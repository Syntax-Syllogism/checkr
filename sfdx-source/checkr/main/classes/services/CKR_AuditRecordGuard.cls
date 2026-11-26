/**
 * Protects audit history, including instance cascades and item lookup clearing.
 */
public inherited sharing class CKR_AuditRecordGuard {
  public static final String REFERENCED_RULE_MESSAGE =
    'Gate rules referenced by bypass history cannot be deleted. Export the history and ask CheckR Audit Maintenance to remove the linked bypass events first.';

  public static final String MESSAGE =
    'CheckR audit records are append-only. Ask an administrator with CheckR Audit Maintenance.';

  /**
   * Blocks deleting templates or versions with gate rules referenced by bypass history.
   * @param records trigger records being checked
   */
  public static void validateGateRuleParentDeletes(List<SObject> records) {
    if (records.isEmpty()) {
      return;
    }
    CKR_IAuditRetentionSelector selector =
      (CKR_IAuditRetentionSelector) CKR_AppFactory.getInstance(
        CKR_IAuditRetentionSelector.class
      );
    Set<Id> parentIds = new Set<Id>();
    for (SObject row : records) {
      parentIds.add(row.Id);
    }
    Set<Id> protectedIds =
      records[0].getSObjectType() == CKR_ChecklistTemplate__c.SObjectType
      ? selector.selectBypassReferencedTemplateIds(parentIds)
      : selector.selectBypassReferencedVersionIds(parentIds);
    for (SObject row : records) {
      if (protectedIds.contains(row.Id)) {
        row.addError(REFERENCED_RULE_MESSAGE);
      }
    }
  }

  /**
   * Rejects protected writes unless the user has CheckR Audit Maintenance.
   * @param records trigger records being checked
   */
  public static void blockUnlessMaintainer(List<SObject> records) {
    if (FeatureManagement.checkPermission('CKR_Audit_Maintenance')) {
      return;
    }
    for (SObject row : records) {
      row.addError(MESSAGE);
    }
  }

  /**
   * Blocks checklist instance deletes that would cascade to audit events.
   * @param records trigger records being checked
   */
  public static void validateInstanceDeletes(
    List<CKR_ChecklistInstance__c> records
  ) {
    if (FeatureManagement.checkPermission('CKR_Audit_Maintenance')) {
      return;
    }
    CKR_IAuditRetentionSelector selector =
      (CKR_IAuditRetentionSelector) CKR_AppFactory.getInstance(
        CKR_IAuditRetentionSelector.class
      );
    Set<Id> protectedIds =
      selector.selectAuditedInstanceIds(
        new Map<Id, CKR_ChecklistInstance__c>(records).keySet()
      );
    List<SObject> protectedRows = new List<SObject>();
    for (CKR_ChecklistInstance__c row : records) {
      if (protectedIds.contains(row.Id)) {
        protectedRows.add(row);
      }
    }
    blockUnlessMaintainer(protectedRows);
  }

  /**
   * Blocks item deletes that would clear audit lookups.
   * @param records trigger records being checked
   */
  public static void validateItemDeletes(
    List<CKR_ChecklistInstanceItem__c> records
  ) {
    if (FeatureManagement.checkPermission('CKR_Audit_Maintenance')) {
      return;
    }
    CKR_IAuditRetentionSelector selector =
      (CKR_IAuditRetentionSelector) CKR_AppFactory.getInstance(
        CKR_IAuditRetentionSelector.class
      );
    Set<Id> protectedIds =
      selector.selectAuditedItemIds(
        new Map<Id, CKR_ChecklistInstanceItem__c>(records).keySet()
      );
    List<SObject> protectedRows = new List<SObject>();
    for (CKR_ChecklistInstanceItem__c row : records) {
      if (protectedIds.contains(row.Id)) {
        protectedRows.add(row);
      }
    }
    blockUnlessMaintainer(protectedRows);
  }
}
