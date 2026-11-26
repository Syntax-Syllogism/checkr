/**
 * CKR_SourceType__c decides which items count toward gate completion. It is a
 * required field, so permission-set FLS cannot make it read-only for users;
 * this trigger enforces immutability after insert for every caller.
 */
public with sharing class CKR_ChecklistInstanceItemTriggerHandler {
  /**
   * Protects historical item links and the type used by gate completion.
   * @param operation current before-trigger operation
   * @param newRecords incoming item records
   * @param oldMap previous item state keyed by ID
   */
  public static void handle(
    System.TriggerOperation operation,
    List<CKR_ChecklistInstanceItem__c> newRecords,
    Map<Id, CKR_ChecklistInstanceItem__c> oldMap
  ) {
    switch on operation {
      when BEFORE_DELETE {
        CKR_AuditRecordGuard.validateItemDeletes(oldMap.values());
      }
      when BEFORE_UPDATE {
        protectSourceType(oldMap, newRecords);
      }
    }
  }

  private static void protectSourceType(
    Map<Id, CKR_ChecklistInstanceItem__c> oldItems,
    List<CKR_ChecklistInstanceItem__c> newItems
  ) {
    for (CKR_ChecklistInstanceItem__c newItem : newItems) {
      CKR_ChecklistInstanceItem__c oldItem = oldItems.get(newItem.Id);
      if (
        oldItem != null
        && newItem.CKR_SourceType__c != oldItem.CKR_SourceType__c
      ) {
        newItem.addError(
          'Source Type cannot be changed after the item is created.'
        );
      }
    }
  }
}
