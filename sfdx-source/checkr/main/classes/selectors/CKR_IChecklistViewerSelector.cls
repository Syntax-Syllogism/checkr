/**
 * Read contract for the record-page checklist viewer.
 */
public interface CKR_IChecklistViewerSelector {
  /**
   * Loads the caller’s visible checklist instances for one parent record.
   * @param parentRecordId parent record ID as stored on checklist instances
   * @return checklist instances attached to the parent
   */
  List<CKR_ChecklistInstance__c> selectInstancesByParentRecordId(
    String parentRecordId
  );

  /**
   * Loads visible items for every checklist shown on the record page.
   * @param checklistInstanceIds IDs of the checklists to display
   * @return checklist items ordered for display
   */
  List<CKR_ChecklistInstanceItem__c> selectItemsByChecklistInstanceIds(
    Set<Id> checklistInstanceIds
  );
}
