/**
 * Supported-object config is non-sensitive metadata that the gate reads for any
 * user, so it is read in system mode. See docs/architecture.md.
 */
public inherited sharing class CKR_DefaultSupportedObjectSelector
  extends CKR_SelectorBase implements CKR_ISupportedObjectSelector {
  private static final String SUPPORTED_OBJECTS_SOQL =
    'SELECT DeveloperName, CKR_ObjectApiName__c, CKR_ObjectLabel__c, CKR_ObjectLabelPlural__c, '
    + 'CKR_Description__c, CKR_Active__c, CKR_SupportsGates__c, CKR_HandlerClassName__c '
    + 'FROM CKR_SupportedObject__mdt '
    + 'WHERE CKR_ObjectApiName__c IN :objectApiNames AND CKR_Active__c = TRUE';

  /**
   * Loads the active CheckR settings for the requested Salesforce objects.
   * @param objectApiNames Salesforce object API names to resolve
   * @return supported-object settings keyed by object API name
   */
  public Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig> selectActiveByObjectApiName(
    Set<String> objectApiNames
  ) {
    Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig> configsByObjectApiName =
      new Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig>();
    if (objectApiNames == null || objectApiNames.isEmpty()) {
      return configsByObjectApiName;
    }

    for (CKR_SupportedObject__mdt record : (List<CKR_SupportedObject__mdt>) querySystemModeWithBinds(
      SUPPORTED_OBJECTS_SOQL,
      new Map<String, Object>{ 'objectApiNames' => objectApiNames }
    )) {
      CKR_SupportedObjectSelector.SupportedObjectConfig config =
        new CKR_SupportedObjectSelector.SupportedObjectConfig();
      config.developerName = record.DeveloperName;
      config.objectApiName = record.CKR_ObjectApiName__c;
      config.objectLabel = record.CKR_ObjectLabel__c;
      config.objectLabelPlural = record.CKR_ObjectLabelPlural__c;
      config.description = record.CKR_Description__c;
      config.active = record.CKR_Active__c;
      config.supportsGates = record.CKR_SupportsGates__c;
      config.handlerClassName = record.CKR_HandlerClassName__c;
      configsByObjectApiName.put(config.objectApiName, config);
    }

    return configsByObjectApiName;
  }
}
