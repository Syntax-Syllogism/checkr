/**
 * Permission checks for single and bulk checklist mutations.
 */
public interface CKR_IChecklistPermissionService {
  /**
   * Checks edit permission for a checklist according to its version’s access mode.
   * @param instanceRecord checklist instance with its template version access mode
   * @return true when the current user can edit the checklist
   */
  Boolean canUpdateChecklistInstance(CKR_ChecklistInstance__c instanceRecord);
  /**
   * Checks edit permission for many checklists with a single parent access lookup.
   * @param instanceRecords checklist instances whose update access is being checked
   * @return edit permission indexed by checklist instance ID
   */
  Map<Id, Boolean> canUpdateChecklistInstances(
    List<CKR_ChecklistInstance__c> instanceRecords
  );
}
