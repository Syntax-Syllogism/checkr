/**
 * Loads templates available to the user in the checklist create action.
 */
public with sharing class CKR_ChecklistCreateContextSelector
  extends CKR_SelectorBase implements CKR_IChecklistCreateContextSelector {
  private static final String TEMPLATES_SOQL =
    'SELECT Id, Name, CKR_Description__c, CKR_CurrentPublishedVersion__c, '
    + 'CKR_CurrentPublishedVersion__r.CKR_Description__c, '
    + 'CKR_CurrentPublishedVersion__r.CKR_VersionNumber__c '
    + 'FROM CKR_ChecklistTemplate__c '
    + 'WHERE CKR_Active__c = TRUE '
    + 'AND CKR_TargetObjectApiName__c = :objectApiName '
    + 'AND CKR_CurrentPublishedVersion__c != NULL '
    + 'ORDER BY Name ASC';

  /**
   * Loads active templates with a published version for the specified object.
   * @param objectApiName API name of the parent Salesforce object
   * @return available templates with their current published versions
   */
  public List<CKR_ChecklistTemplate__c> selectAvailableTemplatesForObject(
    String objectApiName
  ) {
    if (String.isBlank(objectApiName)) {
      return new List<CKR_ChecklistTemplate__c>();
    }

    return (List<CKR_ChecklistTemplate__c>) queryWithBinds(
      TEMPLATES_SOQL,
      new Map<String, Object>{ 'objectApiName' => objectApiName }
    );
  }
}
