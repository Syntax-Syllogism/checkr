/**
 * Read contract for creating an instance from a template version.
 */
public interface CKR_IChecklistInstanceSelector {
  /**
   * Loads the version and its parent template for snapshot creation.
   * @param templateVersionId version ID selected for publication
   * @return the requested version, or null when it is unavailable
   */
  CKR_ChecklistTemplateVersion__c selectTemplateVersionById(
    Id templateVersionId
  );
  /**
   * Follows the template’s publication pointer to its current snapshot.
   * @param templateId checklist template ID
   * @return the current published version, or null when it is unavailable
   */
  CKR_ChecklistTemplateVersion__c selectCurrentPublishedTemplateVersion(
    Id templateId
  );
  /**
   * Loads the active item definitions that will be copied into a new instance.
   * @param templateVersionId version ID selected for publication
   * @return active template items in their configured order
   */
  List<CKR_ChecklistTemplateItem__c> selectActiveTemplateItemsByVersionId(
    Id templateVersionId
  );
  /**
   * Checks whether the template has already been attached to the parent.
   * @param uniqueKey key composed from the parent record and the checklist template IDs
   * @return true when an instance has the given parent-template key
   */
  Boolean existingInstanceExists(String uniqueKey);
}
