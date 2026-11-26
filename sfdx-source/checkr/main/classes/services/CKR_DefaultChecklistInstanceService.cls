/**
 * Creates checklist snapshots from published templates and their active items.
 */
public with sharing class CKR_DefaultChecklistInstanceService
  extends CKR_ServiceBase implements CKR_IChecklistInstanceService {
  /**
   * Creates one checklist for a parent and template when the published version is eligible.
   * @param request parent, template selection, and optional due date
   * @return creation outcome and validation messages
   */
  public CKR_ChecklistInstanceCreateResult createFromTemplate(
    CKR_ChecklistInstanceCreateRequest request
  ) {
    CKR_ChecklistInstanceCreateResult result =
      new CKR_ChecklistInstanceCreateResult();
    List<String> validationMessages = validateCreateRequest(request);
    if (!validationMessages.isEmpty()) {
      result.messages.addAll(validationMessages);
      return result;
    }

    CKR_IChecklistInstanceSelector selector = checklistInstanceSelector();
    CKR_ChecklistTemplateVersion__c templateVersion =
      selectTemplateVersion(selector, request);
    String templateProblem =
      templateVersionProblem(templateVersion, request.parentObjectApiName);
    if (templateProblem != null) {
      result.messages.add(templateProblem);
      return result;
    }

    String uniqueKey =
      buildUniqueKey(
        request.parentRecordId,
        templateVersion.CKR_ChecklistTemplate__c
      );

    if (selector.existingInstanceExists(uniqueKey)) {
      result.messages.add(
          'A checklist instance already exists for this record and template.'
        );
      return result;
    }

    List<CKR_ChecklistTemplateItem__c> templateItems =
      selector.selectActiveTemplateItemsByVersionId(templateVersion.Id);

    CKR_ChecklistInstance__c instanceRecord =
      new CKR_ChecklistInstance__c(
        CKR_ChecklistTemplate__c = templateVersion.CKR_ChecklistTemplate__c,
        CKR_ChecklistTemplateVersion__c = templateVersion.Id,
        CKR_ParentRecordId__c = String.valueOf(request.parentRecordId),
        CKR_ParentObjectApiName__c = request.parentObjectApiName,
        CKR_DueDate__c = request.dueDate,
        CKR_UniqueKey__c = uniqueKey
      );
    insertSnapshot(instanceRecord, templateItems);

    result.success = true;
    result.checklistInstanceId = instanceRecord.Id;
    result.messages.add('Checklist instance created successfully.');
    return result;
  }

  private static String templateVersionProblem(
    CKR_ChecklistTemplateVersion__c templateVersion,
    String parentObjectApiName
  ) {
    if (templateVersion == null) {
      return 'The selected published checklist template could not be found.';
    }

    if (templateVersion.CKR_Status__c != 'Published') {
      return 'Only published checklist template versions can create checklist instances.';
    }

    if (templateVersion.CKR_ChecklistTemplate__r == null) {
      return 'The selected checklist template version is missing its parent template.';
    }

    if (!templateVersion.CKR_ChecklistTemplate__r.CKR_Active__c) {
      return 'The selected checklist template is inactive.';
    }

    if (
      templateVersion.CKR_ChecklistTemplate__r.CKR_TargetObjectApiName__c
      != parentObjectApiName
    ) {
      return 'The selected checklist template does not support the requested parent object.';
    }

    return null;
  }

  private void insertSnapshot(
    CKR_ChecklistInstance__c instanceRecord,
    List<CKR_ChecklistTemplateItem__c> templateItems
  ) {
    Integer requiredItemCount = countRequiredItems(templateItems);
    Boolean isComplete = requiredItemCount == 0;
    instanceRecord.CKR_RequiredItemCount__c = requiredItemCount;
    instanceRecord.CKR_CompletedRequiredItemCount__c = 0;
    instanceRecord.CKR_PercentComplete__c = isComplete ? 100 : 0;
    instanceRecord.CKR_IsOverdue__c =
      instanceRecord.CKR_DueDate__c != null
      && instanceRecord.CKR_DueDate__c < Date.today()
      && !isComplete;

    dmlGateway()
      .doInsert(new List<SObject>{ instanceRecord }, CKR_DmlMode.ALL_OR_NONE);
    if (isComplete) {
      // IsComplete feeds the gate, so users have no FLS to write it; the
      // application sets it in system mode. See docs/architecture.md.
      systemDmlGateway()
        .doUpdate(
          new List<SObject>{
            new CKR_ChecklistInstance__c(
              Id = instanceRecord.Id,
              CKR_IsComplete__c = true
            )
          },
          CKR_DmlMode.ALL_OR_NONE
        );
    }

    List<CKR_ChecklistInstanceItem__c> instanceItems =
      buildInstanceItems(instanceRecord.Id, templateItems);

    if (!instanceItems.isEmpty()) {
      // Template items copy gate-driving fields (SourceType, Required) that
      // users have no FLS to write, so the application inserts them in system
      // mode. See docs/architecture.md.
      systemDmlGateway()
        .doInsert(asSObjects(instanceItems), CKR_DmlMode.ALL_OR_NONE);
    }
  }

  private static List<String> validateCreateRequest(
    CKR_ChecklistInstanceCreateRequest request
  ) {
    List<String> messages = new List<String>();
    if (request == null) {
      messages.add('A checklist creation request is required.');
      return messages;
    }

    if (request.parentRecordId == null) {
      messages.add('A parent record is required.');
    }

    if (String.isBlank(request.parentObjectApiName)) {
      messages.add('A parent object API name is required.');
    }

    if (request.templateId == null && request.templateVersionId == null) {
      messages.add(
        'A checklist template or published template version is required.'
      );
    }

    return messages;
  }

  private static CKR_ChecklistTemplateVersion__c selectTemplateVersion(
    CKR_IChecklistInstanceSelector selector,
    CKR_ChecklistInstanceCreateRequest request
  ) {
    return request.templateVersionId != null
    ? selector.selectTemplateVersionById(request.templateVersionId)
    : selector.selectCurrentPublishedTemplateVersion(request.templateId);
  }

  private static Integer countRequiredItems(
    List<CKR_ChecklistTemplateItem__c> templateItems
  ) {
    Integer requiredItemCount = 0;
    for (CKR_ChecklistTemplateItem__c templateItem : templateItems) {
      if (templateItem.CKR_Required__c) {
        requiredItemCount++;
      }
    }
    return requiredItemCount;
  }

  private static List<CKR_ChecklistInstanceItem__c> buildInstanceItems(
    Id checklistInstanceId,
    List<CKR_ChecklistTemplateItem__c> templateItems
  ) {
    List<CKR_ChecklistInstanceItem__c> instanceItems =
      new List<CKR_ChecklistInstanceItem__c>();
    for (CKR_ChecklistTemplateItem__c templateItem : templateItems) {
      instanceItems.add(
        new CKR_ChecklistInstanceItem__c(
          CKR_ChecklistInstance__c = checklistInstanceId,
          CKR_ChecklistTemplateItem__c = templateItem.Id,
          CKR_SourceType__c = 'Template',
          CKR_LockedFromTemplate__c = true,
          CKR_Label__c = templateItem.CKR_Label__c,
          CKR_Required__c = templateItem.CKR_Required__c,
          CKR_ExplanationRequired__c = templateItem.CKR_ExplanationRequired__c,
          CKR_ExplanationInputType__c =
            normalizeExplanationInputType(
              templateItem.CKR_ExplanationInputType__c
            ),
          CKR_ExplanationPicklistValues__c =
            templateItem.CKR_ExplanationInputType__c == 'Picklist'
            ? templateItem.CKR_ExplanationPicklistValues__c
            : null,
          CKR_AssigneeUser__c = templateItem.CKR_AssigneeUser__c,
          CKR_SortOrder__c = templateItem.CKR_SortOrder__c,
          CKR_Completed__c = false,
          CKR_CheckboxValue__c = false
        )
      );
    }
    return instanceItems;
  }

  private static List<SObject> asSObjects(
    List<CKR_ChecklistInstanceItem__c> records
  ) {
    List<SObject> converted = new List<SObject>();
    converted.addAll(records);
    return converted;
  }

  private static String buildUniqueKey(Id parentRecordId, Id templateId) {
    return String.join(
      new List<String>{
        String.valueOf(parentRecordId),
        String.valueOf(templateId)
      },
      '|'
    );
  }

  private static String normalizeExplanationInputType(
    String explanationInputType
  ) {
    return explanationInputType == 'Picklist' ? 'Picklist' : 'Text';
  }
}
