/**
 * Derives checklist progress and overdue state from required template items.
 */
public inherited sharing class CKR_ChecklistRollup {
  /**
   * Builds the derived-field update for an existing checklist.
   * @param instanceRecord checklist with its due date
   * @param requiredCount number of required template items
   * @param completedCount number of completed required template items
   * @return the checklist ID and derived field updates
   */
  public static CKR_ChecklistInstance__c buildChanges(
    CKR_ChecklistInstance__c instanceRecord,
    Integer requiredCount,
    Integer completedCount
  ) {
    Boolean isComplete = requiredCount == 0 || completedCount >= requiredCount;
    Decimal percentComplete =
      requiredCount == 0
      ? 100
      : ((Decimal) completedCount * 100) / requiredCount;

    return new CKR_ChecklistInstance__c(
      Id = instanceRecord.Id,
      CKR_RequiredItemCount__c = requiredCount,
      CKR_CompletedRequiredItemCount__c = completedCount,
      CKR_IsComplete__c = isComplete,
      CKR_PercentComplete__c = percentComplete.setScale(2),
      CKR_IsOverdue__c =
        instanceRecord.CKR_DueDate__c != null
        && instanceRecord.CKR_DueDate__c < Date.today()
        && !isComplete
    );
  }
}
