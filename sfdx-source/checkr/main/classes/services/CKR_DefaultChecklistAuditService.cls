/**
 * Audit events are system-authored, so this service writes through the
 * system-mode gateway; users get no create access on audit events and can't
 * forge them. See docs/architecture.md.
 */
public with sharing class CKR_DefaultChecklistAuditService
  extends CKR_ServiceBase implements CKR_IChecklistAuditService {
  /**
   * Persists eligible audit events after filling in missing actor and timestamp fields.
   * @param auditEvents events supplied by the checklist operation
   */
  public void record(List<CKR_ChecklistAuditEvent__c> auditEvents) {
    if (auditEvents == null || auditEvents.isEmpty()) {
      return;
    }

    List<CKR_ChecklistAuditEvent__c> recordsToInsert =
      new List<CKR_ChecklistAuditEvent__c>();
    for (CKR_ChecklistAuditEvent__c auditEvent : auditEvents) {
      if (!isRecordable(auditEvent)) {
        continue;
      }
      stampMissingAuditFields(auditEvent);
      recordsToInsert.add(auditEvent);
    }

    if (!recordsToInsert.isEmpty()) {
      systemDmlGateway()
        .doInsert(asSObjects(recordsToInsert), CKR_DmlMode.ALL_OR_NONE);
    }
  }

  private static Boolean isRecordable(CKR_ChecklistAuditEvent__c event) {
    return event != null
      && event.CKR_ChecklistInstance__c != null
      && !String.isBlank(event.CKR_EventType__c);
  }

  private static void stampMissingAuditFields(
    CKR_ChecklistAuditEvent__c event
  ) {
    if (event.CKR_Actor__c == null) {
      event.CKR_Actor__c = UserInfo.getUserId();
    }
    if (event.CKR_OccurredOn__c == null) {
      event.CKR_OccurredOn__c = System.now();
    }
  }

  private static List<SObject> asSObjects(
    List<CKR_ChecklistAuditEvent__c> records
  ) {
    List<SObject> converted = new List<SObject>();
    converted.addAll(records);
    return converted;
  }
}
