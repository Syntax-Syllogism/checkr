trigger CKR_ChecklistTemplateItemTrigger on CKR_ChecklistTemplateItem__c(
  before delete
) {
  (
    (CKR_ITemplateVersionLifecycleService) CKR_AppFactory.getInstance(
      CKR_ITemplateVersionLifecycleService.class
    )
  ).validateDeletes(Trigger.old);
}
