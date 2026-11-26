/**
 * Read contract for active parent object configuration.
 */
public interface CKR_ISupportedObjectSelector {
  /**
   * Loads the active CheckR settings for the requested Salesforce objects.
   * @param objectApiNames Salesforce object API names to resolve
   * @return supported-object settings keyed by object API name
   */
  Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig> selectActiveByObjectApiName(
    Set<String> objectApiNames
  );
}
