/**
 * Read contract for rules and checklist snapshots needed for gate evaluation.
 */
public interface CKR_IChecklistGateSelector {
  /**
   * Loads active gate rules from published and historical snapshots for evaluation.
   * @param objectApiNames Salesforce object API names to resolve
   * @return rules indexed by parent object API name
   */
  Map<String, List<CKR_ChecklistGateRule__c>> selectActivePublishedGateRulesByObjectApiName(
    Set<String> objectApiNames
  );

  /**
   * Loads checklist snapshots for the candidate parent records and rule templates.
   * @param recordIds parent record IDs referenced by the candidate changes
   * @param templateIds template IDs referenced by the candidate rules
   * @return matching instances across the requested parents and templates
   */
  List<CKR_ChecklistInstance__c> selectInstancesByRecordId(
    Set<Id> recordIds,
    Set<Id> templateIds
  );
}
