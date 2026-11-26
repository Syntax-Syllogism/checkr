/**
 * Read contract for published templates in the checklist create action.
 */
public interface CKR_IChecklistCreateContextSelector {
  /**
   * Loads active templates with a published version for the specified object.
   * @param objectApiName API name of the parent Salesforce object
   * @return available templates with their current published versions
   */
  List<CKR_ChecklistTemplate__c> selectAvailableTemplatesForObject(
    String objectApiName
  );
}
