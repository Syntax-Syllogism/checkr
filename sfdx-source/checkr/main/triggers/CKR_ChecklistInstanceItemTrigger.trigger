trigger CKR_ChecklistInstanceItemTrigger on CKR_ChecklistInstanceItem__c(
  before update,
  before delete
) {
  CKR_ChecklistInstanceItemTriggerHandler.handle(
    Trigger.operationType,
    Trigger.new,
    Trigger.oldMap
  );
}
