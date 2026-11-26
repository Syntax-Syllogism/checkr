trigger CKR_ChecklistTemplateVersionTrigger on CKR_ChecklistTemplateVersion__c(
  before insert,
  before update,
  before delete
) {
  CKR_TemplateVersionTriggerHandler.handle(
    Trigger.operationType,
    Trigger.new,
    Trigger.oldMap
  );
}
