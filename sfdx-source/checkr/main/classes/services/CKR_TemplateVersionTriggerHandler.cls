/**
 * Routes before-save and before-delete checks for checklist template versions.
 */
public inherited sharing class CKR_TemplateVersionTriggerHandler {
  /**
   * Enforces version lifecycle and bypass audit retention at the trigger boundary.
   * @param operation current before-trigger operation
   * @param newRecords version records being saved
   * @param oldMap previous version state keyed by ID
   */
  public static void handle(
    System.TriggerOperation operation,
    List<CKR_ChecklistTemplateVersion__c> newRecords,
    Map<Id, CKR_ChecklistTemplateVersion__c> oldMap
  ) {
    CKR_ITemplateVersionLifecycleService service =
      (CKR_ITemplateVersionLifecycleService) CKR_AppFactory.getInstance(
        CKR_ITemplateVersionLifecycleService.class
      );
    switch on operation {
      when BEFORE_DELETE {
        CKR_AuditRecordGuard.validateGateRuleParentDeletes(oldMap.values());
        service.validateDeletes(oldMap.values());
      }
      when BEFORE_INSERT, BEFORE_UPDATE {
        service.validateVersions(newRecords, oldMap);
      }
    }
  }
}
