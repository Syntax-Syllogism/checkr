trigger CKR_ChecklistInstanceGuard on CKR_ChecklistInstance__c(before delete) {
  CKR_AuditRecordGuard.validateInstanceDeletes(Trigger.old);
}
