/**
 * Read and locking contract for version publication and lifecycle guards.
 */
public interface CKR_IChecklistTemplateVersionSelector {
  /**
   * Loads one version for lifecycle validation or publication.
   * @param versionId checklist template version ID
   * @return the requested version, or null when it is unavailable
   */
  CKR_ChecklistTemplateVersion__c selectVersion(Id versionId);
  /**
   * Locks the template row so publishers cannot change its active version concurrently.
   * @param templateId checklist template ID
   * @return the locked template, or null when it is unavailable
   */
  CKR_ChecklistTemplate__c lockTemplate(Id templateId);
  /**
   * Finds the versions that must become historical during a cutover.
   * @param templateId checklist template ID
   * @return the template’s currently published versions
   */
  List<CKR_ChecklistTemplateVersion__c> selectPublishedVersions(Id templateId);
  /**
   * Loads multiple versions for bulk lifecycle validation.
   * @param versionIds checklist template version IDs
   * @return visible versions matching the requested IDs
   */
  List<CKR_ChecklistTemplateVersion__c> selectVersions(Set<Id> versionIds);
  /**
   * Counts the items configured for the version being published.
   * @param versionId checklist template version ID
   * @return the number of items on the version
   */
  Integer countItems(Id versionId);
}
