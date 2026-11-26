/**
 * Loads checklist summaries and applies edits from the record-page viewer.
 */
public with sharing class CKR_ChecklistViewerController {
  /**
   * Groups all visible checklist instances for the requested parent record.
   */
  public class ChecklistViewerResponse {
    @AuraEnabled
    public String recordId;
    @AuraEnabled
    public List<ChecklistSummary> checklists = new List<ChecklistSummary>();
  }

  /**
   * Carries instance progress, edit permission, and ordered checklist items.
   */
  public class ChecklistSummary {
    @AuraEnabled
    public String checklistInstanceId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String ownerName;
    @AuraEnabled
    public Boolean isComplete;
    @AuraEnabled
    public Boolean isOverdue;
    @AuraEnabled
    public Decimal percentComplete;
    @AuraEnabled
    public Date dueDate;
    @AuraEnabled
    public Boolean canEditItems;
    @AuraEnabled
    public String permissionMessage;
    @AuraEnabled
    public List<ChecklistItemSummary> items = new List<ChecklistItemSummary>();
  }

  /**
   * Carries an item’s current answer and explanation settings to the viewer.
   */
  public class ChecklistItemSummary {
    @AuraEnabled
    public String checklistItemId;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Boolean required;
    @AuraEnabled
    public Boolean completed;
    @AuraEnabled
    public Boolean checkboxValue;
    @AuraEnabled
    public String explanation;
    @AuraEnabled
    public String explanationInputType;
    @AuraEnabled
    public String explanationPicklistValues;
    @AuraEnabled
    public String assigneeUserId;
    @AuraEnabled
    public String assigneeName;
    @AuraEnabled
    public Boolean canEdit;
    @AuraEnabled
    public Boolean isAdHoc;
    @AuraEnabled
    public Boolean explanationRequired;
  }

  private static CKR_IChecklistViewerSelector viewerSelector() {
    return (CKR_IChecklistViewerSelector) CKR_AppFactory.getInstance(
      CKR_IChecklistViewerSelector.class
    );
  }

  private static CKR_IChecklistMutationSelector mutationSelector() {
    return (CKR_IChecklistMutationSelector) CKR_AppFactory.getInstance(
      CKR_IChecklistMutationSelector.class
    );
  }

  private static CKR_IChecklistPermissionService permissionService() {
    return (CKR_IChecklistPermissionService) CKR_AppFactory.getInstance(
      CKR_IChecklistPermissionService.class
    );
  }

  private static CKR_IChecklistAuditService auditService() {
    return (CKR_IChecklistAuditService) CKR_AppFactory.getInstance(
      CKR_IChecklistAuditService.class
    );
  }

  private static CKR_IDmlGateway dmlGateway() {
    return (CKR_IDmlGateway) CKR_AppFactory.getInstance(CKR_IDmlGateway.class);
  }

  private static CKR_ISystemDmlGateway systemDmlGateway() {
    return (CKR_ISystemDmlGateway) CKR_AppFactory.getInstance(
      CKR_ISystemDmlGateway.class
    );
  }

  /**
   * Loads visible instances and items and computes edit permissions in bulk.
   * @param recordId parent record ID
   * @return checklist summaries for the parent record
   */
  @AuraEnabled(cacheable=true)
  public static ChecklistViewerResponse getRecordChecklists(Id recordId) {
    ChecklistViewerResponse response = new ChecklistViewerResponse();
    response.recordId = recordId == null ? null : String.valueOf(recordId);
    if (recordId == null) {
      return response;
    }

    CKR_IChecklistViewerSelector selector = viewerSelector();
    List<CKR_ChecklistInstance__c> instanceRecords =
      selector.selectInstancesByParentRecordId(String.valueOf(recordId));

    Map<Id, Boolean> canEditByInstanceId =
      permissionService().canUpdateChecklistInstances(instanceRecords);

    Map<Id, ChecklistSummary> summariesById = new Map<Id, ChecklistSummary>();
    for (CKR_ChecklistInstance__c instanceRecord : instanceRecords) {
      ChecklistSummary summary =
        toChecklistSummary(instanceRecord, canEditByInstanceId);
      response.checklists.add(summary);
      summariesById.put(instanceRecord.Id, summary);
    }

    if (summariesById.isEmpty()) {
      return response;
    }

    for (CKR_ChecklistInstanceItem__c itemRecord : selector.selectItemsByChecklistInstanceIds(
      summariesById.keySet()
    )) {
      ChecklistSummary summary =
        summariesById.get(itemRecord.CKR_ChecklistInstance__c);
      if (summary == null) {
        continue;
      }

      summary.items.add(toChecklistItemSummary(itemRecord, summary));
    }

    return response;
  }

  /**
   * Updates the item answer and assignee, records changes, and refreshes progress.
   * @param request request from the caller
   */
  @AuraEnabled
  public static void updateChecklistItem(
    CKR_ChecklistItemUpdateRequest request
  ) {
    CKR_ChecklistItemMutation.validateUpdateRequest(request);

    CKR_IChecklistMutationSelector selector = mutationSelector();
    CKR_ChecklistInstanceItem__c itemRecord =
      selector.selectChecklistItemById(request.checklistItemId);
    if (itemRecord == null) {
      throw new AuraHandledException(
        'The requested checklist item was not found.'
      );
    }

    CKR_ChecklistInstanceItem__c oldItemRecord =
      itemRecord.clone(true, false, false, false);

    enforceChecklistPermission(itemRecord.CKR_ChecklistInstance__r);
    CKR_ChecklistItemMutation.applyUpdate(itemRecord, request);

    List<CKR_ChecklistAuditEvent__c> auditEvents =
      CKR_ChecklistItemAuditBuilder.buildUpdateAuditEvents(
        oldItemRecord,
        itemRecord
      );

    dmlGateway()
      .doUpdate(
        new List<SObject>{ CKR_ChecklistItemMutation.itemChanges(itemRecord) },
        CKR_DmlMode.ALL_OR_NONE
      );
    // Completion state feeds the rollup gate, so it is written in system mode
    // and users have no direct edit access to it. See docs/architecture.md.
    systemDmlGateway()
      .doUpdate(
        new List<SObject>{
          new CKR_ChecklistInstanceItem__c(
            Id = itemRecord.Id,
            CKR_Completed__c = itemRecord.CKR_Completed__c,
            CKR_CompletedBy__c = itemRecord.CKR_CompletedBy__c,
            CKR_CompletedOn__c = itemRecord.CKR_CompletedOn__c
          )
        },
        CKR_DmlMode.ALL_OR_NONE
      );
    auditService().record(auditEvents);
    updateChecklistInstanceRollup(itemRecord.CKR_ChecklistInstance__c);
  }

  /**
   * Appends an optional item to the checklist and records its creation.
   * @param request request from the caller
   */
  @AuraEnabled
  public static void addAdHocItem(CKR_AdHocItemRequest request) {
    CKR_ChecklistItemMutation.validateAdHocRequest(request);

    CKR_IChecklistMutationSelector selector = mutationSelector();
    CKR_ChecklistInstance__c instanceRecord =
      selector.selectChecklistInstanceById(request.checklistInstanceId);
    if (instanceRecord == null) {
      throw new AuraHandledException(
        'The requested checklist instance was not found.'
      );
    }

    enforceChecklistPermission(instanceRecord);

    Decimal nextSortOrder =
      selector.selectNextAdHocSortOrder(request.checklistInstanceId);

    CKR_ChecklistInstanceItem__c newItem =
      CKR_ChecklistItemMutation.buildAdHocItem(request, nextSortOrder);
    dmlGateway()
      .doInsert(new List<SObject>{ newItem }, CKR_DmlMode.ALL_OR_NONE);

    auditService()
      .record(
        new List<CKR_ChecklistAuditEvent__c>{
          new CKR_ChecklistAuditEvent__c(
            CKR_ChecklistInstance__c = request.checklistInstanceId,
            CKR_ChecklistInstanceItem__c = newItem.Id,
            CKR_EventType__c = 'AdHocItemAdded',
            CKR_NewValue__c = newItem.CKR_Label__c,
            CKR_Details__c = 'Ad hoc item created'
          )
        }
      );
  }

  /**
   * Audits and removes an ad hoc item from an editable checklist.
   * @param checklistItemId ID of the checklist item
   */
  @AuraEnabled
  public static void removeAdHocItem(Id checklistItemId) {
    if (checklistItemId == null) {
      throw new AuraHandledException('A checklist item is required.');
    }

    CKR_ChecklistInstanceItem__c itemRecord =
      mutationSelector().selectChecklistItemById(checklistItemId);
    if (itemRecord == null) {
      throw new AuraHandledException(
        'The requested checklist item was not found.'
      );
    }

    if (itemRecord.CKR_SourceType__c != 'AdHoc') {
      throw new AuraHandledException(
        'Only ad hoc checklist items can be removed.'
      );
    }

    enforceChecklistPermission(itemRecord.CKR_ChecklistInstance__r);
    auditService()
      .record(
        new List<CKR_ChecklistAuditEvent__c>{
          new CKR_ChecklistAuditEvent__c(
            CKR_ChecklistInstance__c = itemRecord.CKR_ChecklistInstance__c,
            CKR_ChecklistInstanceItem__c = itemRecord.Id,
            CKR_EventType__c = 'AdHocItemRemoved',
            CKR_OldValue__c = String.valueOf(itemRecord.Id),
            CKR_Details__c = 'Ad hoc item removed'
          )
        }
      );
    dmlGateway()
      .doDelete(new List<SObject>{ itemRecord }, CKR_DmlMode.ALL_OR_NONE);
  }

  private static void enforceChecklistPermission(
    CKR_ChecklistInstance__c instanceRecord
  ) {
    if (!permissionService().canUpdateChecklistInstance(instanceRecord)) {
      throw new AuraHandledException(
        'You do not have permission to update checklist items for this checklist.'
      );
    }
  }

  private static ChecklistSummary toChecklistSummary(
    CKR_ChecklistInstance__c instanceRecord,
    Map<Id, Boolean> canEditByInstanceId
  ) {
    ChecklistSummary summary = new ChecklistSummary();
    summary.checklistInstanceId = String.valueOf(instanceRecord.Id);
    summary.name =
      instanceRecord.CKR_ChecklistTemplate__r == null
      ? instanceRecord.Name
      : instanceRecord.CKR_ChecklistTemplate__r.Name;
    summary.ownerName =
      instanceRecord.Owner == null ? 'Unassigned' : instanceRecord.Owner.Name;
    summary.isComplete = instanceRecord.CKR_IsComplete__c;
    summary.isOverdue = instanceRecord.CKR_IsOverdue__c;
    summary.percentComplete = instanceRecord.CKR_PercentComplete__c;
    summary.dueDate = instanceRecord.CKR_DueDate__c;
    summary.canEditItems = canEditByInstanceId.get(instanceRecord.Id) == true;
    summary.permissionMessage =
      summary.canEditItems
      ? null
      : 'You do not have permission to update checklist items for this checklist.';
    return summary;
  }

  private static ChecklistItemSummary toChecklistItemSummary(
    CKR_ChecklistInstanceItem__c itemRecord,
    ChecklistSummary summary
  ) {
    ChecklistItemSummary item = new ChecklistItemSummary();
    item.checklistItemId = String.valueOf(itemRecord.Id);
    item.label = itemRecord.CKR_Label__c;
    item.required = itemRecord.CKR_Required__c;
    item.completed = itemRecord.CKR_Completed__c;
    item.checkboxValue = itemRecord.CKR_CheckboxValue__c;
    item.explanation = itemRecord.CKR_Explanation__c;
    item.explanationInputType =
      CKR_ChecklistItemMutation.normalizeExplanationInputType(
        itemRecord.CKR_ExplanationInputType__c
      );
    item.explanationPicklistValues =
      itemRecord.CKR_ExplanationPicklistValues__c;
    item.assigneeUserId =
      itemRecord.CKR_AssigneeUser__c == null
      ? null
      : String.valueOf(itemRecord.CKR_AssigneeUser__c);
    item.assigneeName = null;
    item.canEdit = summary.canEditItems;
    item.isAdHoc = itemRecord.CKR_SourceType__c == 'AdHoc';
    item.explanationRequired = itemRecord.CKR_ExplanationRequired__c;
    return item;
  }

  private static void updateChecklistInstanceRollup(Id checklistInstanceId) {
    if (checklistInstanceId == null) {
      return;
    }

    CKR_IChecklistMutationSelector selector = mutationSelector();
    CKR_ChecklistInstance__c instanceRecord =
      selector.selectChecklistInstanceForRollup(checklistInstanceId);
    if (instanceRecord == null) {
      return;
    }

    Integer requiredCount =
      selector.countRequiredTemplateItems(checklistInstanceId);

    Integer completedCount =
      selector.countCompletedRequiredTemplateItems(checklistInstanceId);

    // Derived rollup state (IsComplete feeds the parent-save gate) is written
    // in system mode so users cannot set it directly. See docs/architecture.md.
    systemDmlGateway()
      .doUpdate(
        new List<SObject>{
          CKR_ChecklistRollup.buildChanges(
            instanceRecord,
            requiredCount,
            completedCount
          )
        },
        CKR_DmlMode.ALL_OR_NONE
      );
  }
}
