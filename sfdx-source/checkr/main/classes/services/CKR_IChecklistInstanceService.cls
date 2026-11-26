/**
 * Creation contract for snapshotting a published checklist template.
 */
public interface CKR_IChecklistInstanceService {
  /**
   * Snapshots the selected published template into an instance and its items.
   * @param request request from the caller
   * @return creation outcome and validation messages
   */
  CKR_ChecklistInstanceCreateResult createFromTemplate(
    CKR_ChecklistInstanceCreateRequest request
  );
}
