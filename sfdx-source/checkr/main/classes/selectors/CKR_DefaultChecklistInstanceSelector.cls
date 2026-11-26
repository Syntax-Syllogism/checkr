/**
 * Loads published template snapshots and checks for duplicate instances.
 */
public with sharing class CKR_DefaultChecklistInstanceSelector
  extends CKR_SelectorBase implements CKR_IChecklistInstanceSelector {
  private static final String VERSION_BY_ID_SOQL =
    'SELECT Id, CKR_Status__c, CKR_ChecklistTemplate__c, CKR_ChecklistTemplate__r.Name, '
    + 'CKR_ChecklistTemplate__r.CKR_Active__c, CKR_ChecklistTemplate__r.CKR_TargetObjectApiName__c '
    + 'FROM CKR_ChecklistTemplateVersion__c '
    + 'WHERE Id = :templateVersionId LIMIT 1';

  private static final String CURRENT_VERSION_SOQL =
    'SELECT Id, CKR_Status__c, CKR_ChecklistTemplate__c, CKR_ChecklistTemplate__r.Name, '
    + 'CKR_ChecklistTemplate__r.CKR_Active__c, CKR_ChecklistTemplate__r.CKR_TargetObjectApiName__c '
    + 'FROM CKR_ChecklistTemplateVersion__c '
    + 'WHERE CKR_ChecklistTemplate__c = :templateId '
    + 'AND Id IN (SELECT CKR_CurrentPublishedVersion__c FROM CKR_ChecklistTemplate__c WHERE Id = :templateId) '
    + 'LIMIT 1';

  private static final String TEMPLATE_ITEMS_SOQL =
    'SELECT Id, CKR_Label__c, CKR_Required__c, CKR_ExplanationRequired__c, '
    + 'CKR_ExplanationInputType__c, CKR_ExplanationPicklistValues__c, '
    + 'CKR_AssigneeUser__c, CKR_SortOrder__c '
    + 'FROM CKR_ChecklistTemplateItem__c '
    + 'WHERE CKR_ChecklistTemplateVersion__c = :templateVersionId AND CKR_Active__c = TRUE '
    + 'ORDER BY CKR_SortOrder__c ASC, CreatedDate ASC';

  private static final String EXISTING_INSTANCE_SOQL =
    'SELECT COUNT() FROM CKR_ChecklistInstance__c WHERE CKR_UniqueKey__c = :uniqueKey';

  /**
   * Loads the version and its parent template for snapshot creation.
   * @param templateVersionId version ID selected for publication
   * @return the requested version, or null when it is unavailable
   */
  public CKR_ChecklistTemplateVersion__c selectTemplateVersionById(
    Id templateVersionId
  ) {
    List<CKR_ChecklistTemplateVersion__c> versions =
      (List<CKR_ChecklistTemplateVersion__c>) queryWithBinds(
        VERSION_BY_ID_SOQL,
        new Map<String, Object>{ 'templateVersionId' => templateVersionId }
      );
    return versions.isEmpty() ? null : versions[0];
  }

  /**
   * Follows the template’s publication pointer to its current snapshot.
   * @param templateId checklist template ID
   * @return the current published version, or null when it is unavailable
   */
  public CKR_ChecklistTemplateVersion__c selectCurrentPublishedTemplateVersion(
    Id templateId
  ) {
    List<CKR_ChecklistTemplateVersion__c> versions =
      (List<CKR_ChecklistTemplateVersion__c>) queryWithBinds(
        CURRENT_VERSION_SOQL,
        new Map<String, Object>{ 'templateId' => templateId }
      );
    return versions.isEmpty() ? null : versions[0];
  }

  /**
   * Loads the active item definitions that will be copied into a new instance.
   * @param templateVersionId version ID selected for publication
   * @return active template items in their configured order
   */
  public List<CKR_ChecklistTemplateItem__c> selectActiveTemplateItemsByVersionId(
    Id templateVersionId
  ) {
    return (List<CKR_ChecklistTemplateItem__c>) queryWithBinds(
      TEMPLATE_ITEMS_SOQL,
      new Map<String, Object>{ 'templateVersionId' => templateVersionId }
    );
  }

  /**
   * Checks whether the template has already been attached to the parent.
   * @param uniqueKey key composed from the parent record and the checklist template IDs
   * @return true when an instance has the given parent-template key
   */
  public Boolean existingInstanceExists(String uniqueKey) {
    return countWithBinds(
        EXISTING_INSTANCE_SOQL,
        new Map<String, Object>{ 'uniqueKey' => uniqueKey }
      )
      > 0;
  }
}
