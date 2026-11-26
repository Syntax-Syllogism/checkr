trigger CKR_ChecklistGateRuleTrigger on CKR_ChecklistGateRule__c(
  before delete
) {
  (
    (CKR_ITemplateVersionLifecycleService) CKR_AppFactory.getInstance(
      CKR_ITemplateVersionLifecycleService.class
    )
  ).validateDeletes(Trigger.old);
}
