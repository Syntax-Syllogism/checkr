/**
 * Gate reads run in system mode: the gate fires from parent-object triggers for
 * any user, including users with no checkr permission set, so it must see the
 * rules and instances regardless of the running user's CRUD/FLS. See
 * docs/architecture.md.
 */
public inherited sharing class CKR_ChecklistGateSelector
  extends CKR_SelectorBase implements CKR_IChecklistGateSelector {
  private static final String GATE_RULES_SOQL =
    'SELECT Id, Name, CKR_ChecklistTemplateVersion__c, CKR_ProtectedActionType__c, '
    + 'CKR_TargetFieldApiName__c, CKR_TargetValue__c, CKR_TargetValueSet__c, '
    + 'CKR_ErrorMessage__c, CKR_SortOrder__c, CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__c, CKR_ChecklistTemplateVersion__r.CKR_Status__c, '
    + 'CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__r.CKR_TargetObjectApiName__c '
    + 'FROM CKR_ChecklistGateRule__c '
    + 'WHERE CKR_Active__c = TRUE '
    + 'AND CKR_ChecklistTemplateVersion__r.CKR_Status__c IN (\'Published\', \'Historical\') '
    + 'AND CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__r.CKR_TargetObjectApiName__c IN :objectApiNames '
    + 'ORDER BY CKR_SortOrder__c ASC, CreatedDate ASC';

  /**
   * Loads active gate rules on Published and Historical template versions, grouped by parent object.
   *
   * @param objectApiNames parent object API names to load rules for
   * @return gate rules keyed by parent object API name
   */
  public Map<String, List<CKR_ChecklistGateRule__c>> selectActivePublishedGateRulesByObjectApiName(
    Set<String> objectApiNames
  ) {
    Map<String, List<CKR_ChecklistGateRule__c>> gateRulesByObjectApiName =
      new Map<String, List<CKR_ChecklistGateRule__c>>();
    if (objectApiNames == null || objectApiNames.isEmpty()) {
      return gateRulesByObjectApiName;
    }

    for (CKR_ChecklistGateRule__c gateRule : (List<CKR_ChecklistGateRule__c>) querySystemModeWithBinds(
      GATE_RULES_SOQL,
      new Map<String, Object>{ 'objectApiNames' => objectApiNames }
    )) {
      String objectApiName =
        gateRule.CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__r.CKR_TargetObjectApiName__c;
      if (!gateRulesByObjectApiName.containsKey(objectApiName)) {
        gateRulesByObjectApiName.put(
          objectApiName,
          new List<CKR_ChecklistGateRule__c>()
        );
      }
      gateRulesByObjectApiName.get(objectApiName).add(gateRule);
    }

    return gateRulesByObjectApiName;
  }

  /**
   * Loads checklist snapshots for the candidate parent records and rule templates.
   * @param recordIds parent record IDs referenced by the candidate changes
   * @param templateIds template IDs referenced by the candidate rules
   * @return matching instances across the requested parents and templates
   */
  public List<CKR_ChecklistInstance__c> selectInstancesByRecordId(
    Set<Id> recordIds,
    Set<Id> templateIds
  ) {
    if (
      recordIds == null
      || recordIds.isEmpty()
      || templateIds == null
      || templateIds.isEmpty()
    ) {
      return new List<CKR_ChecklistInstance__c>();
    }
    Set<String> parentRecordIds = new Set<String>();
    for (Id recordId : recordIds) {
      parentRecordIds.add(String.valueOf(recordId));
    }
    return (List<CKR_ChecklistInstance__c>) querySystemModeWithBinds(
      'SELECT Id, CKR_ParentRecordId__c, CKR_ChecklistTemplate__c, CKR_ChecklistTemplateVersion__c, CKR_IsComplete__c FROM CKR_ChecklistInstance__c WHERE CKR_ParentRecordId__c IN :parentRecordIds AND CKR_ChecklistTemplate__c IN :templateIds',
      new Map<String, Object>{
        'parentRecordIds' => parentRecordIds,
        'templateIds' => templateIds
      }
    );
  }
}
