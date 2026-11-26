/**
 * Evaluates checklist edit permission against the parent record and template mode.
 */
public with sharing class CKR_DefaultChecklistPermissionService
  extends CKR_ServiceBase implements CKR_IChecklistPermissionService {
  /**
   * Checks edit permission for a checklist according to its version’s access mode.
   * @param instanceRecord checklist instance with its template version access mode
   * @return true when the current user can edit the checklist
   */
  public Boolean canUpdateChecklistInstance(
    CKR_ChecklistInstance__c instanceRecord
  ) {
    if (instanceRecord == null) {
      return false;
    }

    Map<Id, Boolean> accessByInstanceId =
      canUpdateChecklistInstances(
        new List<CKR_ChecklistInstance__c>{ instanceRecord }
      );
    return accessByInstanceId.containsKey(instanceRecord.Id)
      && accessByInstanceId.get(instanceRecord.Id);
  }

  /**
   * Checks edit permission for many checklists with a single parent access lookup.
   * @param instanceRecords checklist instances whose update access is being checked
   * @return edit permission indexed by checklist instance ID
   */
  public Map<Id, Boolean> canUpdateChecklistInstances(
    List<CKR_ChecklistInstance__c> instanceRecords
  ) {
    Map<Id, Boolean> results = new Map<Id, Boolean>();
    if (instanceRecords == null || instanceRecords.isEmpty()) {
      return results;
    }

    Map<Id, CKR_ParentAccess> accessByParentId =
      loadParentAccess(instanceRecords);
    for (CKR_ChecklistInstance__c instanceRecord : instanceRecords) {
      if (instanceRecord == null || instanceRecord.Id == null) {
        continue;
      }

      Id parentRecordId = parseId(instanceRecord.CKR_ParentRecordId__c);
      CKR_ParentAccess parentAccess =
        parentRecordId == null ? null : accessByParentId.get(parentRecordId);

      results.put(
        instanceRecord.Id,
        isAllowedForMode(
          parentAccess,
          completionAccessMode(instanceRecord),
          customPermissionDeveloperName(instanceRecord)
        )
      );
    }

    return results;
  }

  private Map<Id, CKR_ParentAccess> loadParentAccess(
    List<CKR_ChecklistInstance__c> instanceRecords
  ) {
    Set<Id> parentRecordIds = new Set<Id>();
    for (CKR_ChecklistInstance__c instanceRecord : instanceRecords) {
      Id parentRecordId =
        instanceRecord == null
        ? null
        : parseId(instanceRecord.CKR_ParentRecordId__c);
      if (parentRecordId != null) {
        parentRecordIds.add(parentRecordId);
      }
    }

    Map<Id, CKR_ParentAccess> accessByParentId =
      new Map<Id, CKR_ParentAccess>();
    if (parentRecordIds.isEmpty()) {
      return accessByParentId;
    }

    return parentAccessGateway().loadParentAccess(parentRecordIds);
  }

  private Boolean isAllowedForMode(
    CKR_ParentAccess parentAccess,
    String completionAccessMode,
    String customPermissionDeveloperName
  ) {
    if (parentAccess == null || !parentAccess.hasReadAccess) {
      return false;
    }

    if (completionAccessMode == 'EditAccess') {
      return parentAccess.hasEditAccess;
    }

    if (completionAccessMode == 'CustomPermission') {
      return parentAccessGateway()
        .hasCustomPermission(customPermissionDeveloperName);
    }

    return true;
  }

  private static Id parseId(String rawValue) {
    if (String.isBlank(rawValue)) {
      return null;
    }

    try {
      return (Id) rawValue;
    } catch (Exception ex) {
      return null;
    }
  }

  private static String completionAccessMode(
    CKR_ChecklistInstance__c instanceRecord
  ) {
    return instanceRecord.CKR_ChecklistTemplateVersion__r == null
    ? null
    : instanceRecord.CKR_ChecklistTemplateVersion__r.CKR_CompletionAccessMode__c;
  }

  private static String customPermissionDeveloperName(
    CKR_ChecklistInstance__c instanceRecord
  ) {
    return instanceRecord.CKR_ChecklistTemplateVersion__r == null
    ? null
    : instanceRecord.CKR_ChecklistTemplateVersion__r.CKR_CustomPermissionDeveloperName__c;
  }
}
