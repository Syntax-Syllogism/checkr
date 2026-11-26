/**
 * Read contract for editing checklist items and recalculating instance progress.
 */
public interface CKR_IChecklistMutationSelector {
  /**
   * Loads a checklist item and the instance needed to check edit access.
   * @param checklistItemId ID of the checklist item
   * @return visible item with mutation context, or null
   */
  CKR_ChecklistInstanceItem__c selectChecklistItemById(Id checklistItemId);
  /**
   * Loads the instance and its parent access mode before creating an item.
   * @param checklistInstanceId ID of the checklist instance
   * @return visible instance with mutation context, or null
   */
  CKR_ChecklistInstance__c selectChecklistInstanceById(Id checklistInstanceId);
  /**
   * Determines where a new ad hoc item belongs after existing items.
   * @param checklistInstanceId ID of the checklist instance
   * @return the next sort order for the checklist
   */
  Decimal selectNextAdHocSortOrder(Id checklistInstanceId);
  /**
   * Loads the values needed to recalculate checklist progress and overdue status.
   * @param checklistInstanceId ID of the checklist instance
   * @return visible instance with rollup context, or null
   */
  CKR_ChecklistInstance__c selectChecklistInstanceForRollup(
    Id checklistInstanceId
  );
  /**
   * Counts required items copied from the template for gate progress.
   * @param checklistInstanceId ID of the checklist instance
   * @return the number of qualifying items
   */
  Integer countRequiredTemplateItems(Id checklistInstanceId);
  /**
   * Counts completed required template items for gate progress.
   * @param checklistInstanceId ID of the checklist instance
   * @return the number of qualifying completed items
   */
  Integer countCompletedRequiredTemplateItems(Id checklistInstanceId);
}
