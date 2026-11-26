/**
 * Loads versions and locks templates for publication and lifecycle checks.
 */
public with sharing class CKR_ChecklistTemplateVersionSelector
  extends CKR_SelectorBase implements CKR_IChecklistTemplateVersionSelector {
  /**
   * Loads one version for lifecycle validation or publication.
   * @param versionId checklist template version ID
   * @return the requested version, or null when it is unavailable
   */
  public CKR_ChecklistTemplateVersion__c selectVersion(Id versionId) {
    List<CKR_ChecklistTemplateVersion__c> versions =
      (List<CKR_ChecklistTemplateVersion__c>) queryWithBinds(
        'SELECT Id, CKR_ChecklistTemplate__c, CKR_Status__c FROM CKR_ChecklistTemplateVersion__c WHERE Id = :versionId',
        new Map<String, Object>{ 'versionId' => versionId }
      );
    return versions.isEmpty() ? null : versions[0];
  }
  /**
   * Locks the template row so publishers cannot change its active version concurrently.
   * @param templateId checklist template ID
   * @return the locked template, or null when it is unavailable
   */
  public CKR_ChecklistTemplate__c lockTemplate(Id templateId) {
    List<CKR_ChecklistTemplate__c> templates =
      (List<CKR_ChecklistTemplate__c>) queryWithBinds(
        'SELECT Id FROM CKR_ChecklistTemplate__c WHERE Id = :templateId FOR UPDATE',
        new Map<String, Object>{ 'templateId' => templateId }
      );
    return templates.isEmpty() ? null : templates[0];
  }
  /**
   * Finds the versions that must become historical during a cutover.
   * @param templateId checklist template ID
   * @return the template’s currently published versions
   */
  public List<CKR_ChecklistTemplateVersion__c> selectPublishedVersions(
    Id templateId
  ) {
    return (List<CKR_ChecklistTemplateVersion__c>) queryWithBinds(
      'SELECT Id FROM CKR_ChecklistTemplateVersion__c WHERE CKR_ChecklistTemplate__c = :templateId AND CKR_Status__c = \'Published\'',
      new Map<String, Object>{ 'templateId' => templateId }
    );
  }
  /**
   * Loads multiple versions for bulk lifecycle validation.
   * @param versionIds checklist template version IDs
   * @return visible versions matching the requested IDs
   */
  public List<CKR_ChecklistTemplateVersion__c> selectVersions(
    Set<Id> versionIds
  ) {
    return (List<CKR_ChecklistTemplateVersion__c>) queryWithBinds(
      'SELECT Id, CKR_Status__c FROM CKR_ChecklistTemplateVersion__c WHERE Id IN :versionIds',
      new Map<String, Object>{ 'versionIds' => versionIds }
    );
  }
  /**
   * Counts the items configured for the version being published.
   * @param versionId checklist template version ID
   * @return the number of items on the version
   */
  public Integer countItems(Id versionId) {
    return countWithBinds(
      'SELECT COUNT() FROM CKR_ChecklistTemplateItem__c WHERE CKR_ChecklistTemplateVersion__c = :versionId',
      new Map<String, Object>{ 'versionId' => versionId }
    );
  }
}
