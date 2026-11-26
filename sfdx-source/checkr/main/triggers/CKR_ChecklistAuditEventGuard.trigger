trigger CKR_ChecklistAuditEventGuard on CKR_ChecklistAuditEvent__c(
  before update,
  before delete
) {
  CKR_AuditRecordGuard.blockUnlessMaintainer(
    Trigger.isDelete ? Trigger.old : Trigger.new
  );
}
