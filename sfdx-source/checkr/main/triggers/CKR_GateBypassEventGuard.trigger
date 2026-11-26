trigger CKR_GateBypassEventGuard on CKR_GateBypassEvent__c(
  before update,
  before delete
) {
  CKR_AuditRecordGuard.blockUnlessMaintainer(
    Trigger.isDelete ? Trigger.old : Trigger.new
  );
}
