/**
 * Builds audit rows for the checklist fields editable in the viewer.
 */
public inherited sharing class CKR_ChecklistItemAuditBuilder {
  private static final Map<String, String> DETAILS_BY_TYPE =
    new Map<String, String>{
      'ItemCompleted' => 'Completion status changed',
      'ItemUncompleted' => 'Completion status changed',
      'AnswerChanged' => 'Checkbox answer changed',
      'ExplanationChanged' => 'Explanation changed',
      'AssigneeChanged' => 'Item assignee changed'
    };

  /**
   * Builds events for changes made by a checklist item update.
   * @param oldItemRecord snapshot before applying the request
   * @param newItemRecord item after applying the request
   * @return the changes eligible for audit, in display order
   */
  public static List<CKR_ChecklistAuditEvent__c> buildUpdateAuditEvents(
    CKR_ChecklistInstanceItem__c oldItemRecord,
    CKR_ChecklistInstanceItem__c newItemRecord
  ) {
    List<CKR_ChecklistAuditEvent__c> auditEvents =
      new List<CKR_ChecklistAuditEvent__c>();
    if (oldItemRecord == null || newItemRecord == null) {
      return auditEvents;
    }

    if (oldItemRecord.CKR_Completed__c != newItemRecord.CKR_Completed__c) {
      auditEvents.add(
        buildAuditEvent(
          newItemRecord.CKR_Completed__c ? 'ItemCompleted' : 'ItemUncompleted',
          String.valueOf(oldItemRecord.CKR_Completed__c),
          String.valueOf(newItemRecord.CKR_Completed__c)
        )
      );
    }

    if (
      oldItemRecord.CKR_CheckboxValue__c != newItemRecord.CKR_CheckboxValue__c
    ) {
      auditEvents.add(
        buildAuditEvent(
          'AnswerChanged',
          String.valueOf(oldItemRecord.CKR_CheckboxValue__c),
          String.valueOf(newItemRecord.CKR_CheckboxValue__c)
        )
      );
    }

    if (oldItemRecord.CKR_Explanation__c != newItemRecord.CKR_Explanation__c) {
      auditEvents.add(
        buildAuditEvent(
          'ExplanationChanged',
          oldItemRecord.CKR_Explanation__c,
          newItemRecord.CKR_Explanation__c
        )
      );
    }

    if (
      oldItemRecord.CKR_AssigneeUser__c != newItemRecord.CKR_AssigneeUser__c
    ) {
      auditEvents.add(
        buildAuditEvent(
          'AssigneeChanged',
          String.valueOf(oldItemRecord.CKR_AssigneeUser__c),
          String.valueOf(newItemRecord.CKR_AssigneeUser__c)
        )
      );
    }

    for (CKR_ChecklistAuditEvent__c event : auditEvents) {
      event.CKR_ChecklistInstance__c = newItemRecord.CKR_ChecklistInstance__c;
      event.CKR_ChecklistInstanceItem__c = newItemRecord.Id;
    }
    return auditEvents;
  }

  private static CKR_ChecklistAuditEvent__c buildAuditEvent(
    String eventType,
    String oldValue,
    String newValue
  ) {
    return new CKR_ChecklistAuditEvent__c(
      CKR_EventType__c = eventType,
      CKR_OldValue__c = oldValue,
      CKR_NewValue__c = newValue,
      CKR_Details__c = DETAILS_BY_TYPE.get(eventType)
    );
  }
}
