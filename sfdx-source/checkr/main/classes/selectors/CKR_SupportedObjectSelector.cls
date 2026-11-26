/**
 * Exposes active supported-object settings through the configured selector.
 */
public with sharing class CKR_SupportedObjectSelector {
  /**
   * Describes how CheckR integrates with one Salesforce object.
   */
  public class SupportedObjectConfig {
    public String developerName;
    public String objectApiName;
    public String objectLabel;
    public String objectLabelPlural;
    public String description;
    public Boolean active;
    public Boolean supportsGates;
    public String handlerClassName;
  }

  /**
   * Loads the active CheckR settings for the requested Salesforce objects.
   * @param objectApiNames Salesforce object API names to resolve
   * @return supported-object settings keyed by object API name
   */
  public static Map<String, SupportedObjectConfig> selectActiveByObjectApiName(
    Set<String> objectApiNames
  ) {
    return (
      (CKR_ISupportedObjectSelector) CKR_AppFactory.getInstance(
        CKR_ISupportedObjectSelector.class
      )
    ).selectActiveByObjectApiName(objectApiNames);
  }
}
