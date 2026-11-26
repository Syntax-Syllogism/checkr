/**
 * Validation contract for guarding trigger-driven version lifecycle changes.
 */
public interface CKR_ITemplateVersionLifecycleService {
  /**
   * Guards lifecycle status and snapshot fields on version insert and update.
   * @param records trigger records being checked
   * @param oldMap previous template versions keyed by ID
   */
  void validateVersions(
    List<CKR_ChecklistTemplateVersion__c> records,
    Map<Id, CKR_ChecklistTemplateVersion__c> oldMap
  );
  /**
   * Rejects direct deletion of versions that are no longer drafts.
   * @param records trigger records being checked
   */
  void validateDeletes(List<SObject> records);
}
