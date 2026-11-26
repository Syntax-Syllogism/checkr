trigger CKR_ChecklistTemplateGuard on CKR_ChecklistTemplate__c(before delete) {
  CKR_AuditRecordGuard.validateGateRuleParentDeletes(Trigger.old);
}
