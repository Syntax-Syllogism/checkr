/**
 * System-mode integrity check must include audit history hidden from the actor.
 */
public without sharing class CKR_AuditRetentionSelector
  extends CKR_SelectorBase implements CKR_IAuditRetentionSelector {
  /**
   * Finds templates with bypass events attached to any version's gate rules.
   * @param templateIds templates considered for deletion
   * @return protected template IDs
   */
  public Set<Id> selectBypassReferencedTemplateIds(Set<Id> templateIds) {
    return selectBypassReferencedIds(
      templateIds,
      'CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__c',
      'CKR_ChecklistTemplate__c'
    );
  }

  /**
   * Finds versions with bypass events attached to their gate rules.
   * @param versionIds versions considered for deletion
   * @return protected version IDs
   */
  public Set<Id> selectBypassReferencedVersionIds(Set<Id> versionIds) {
    return selectBypassReferencedIds(
      versionIds,
      'CKR_ChecklistTemplateVersion__c',
      'CKR_ChecklistTemplateVersion__c'
    );
  }

  private Set<Id> selectBypassReferencedIds(
    Set<Id> parentIds,
    String parentField,
    String resultField
  ) {
    Set<Id> result = new Set<Id>();
    if (parentIds.isEmpty()) {
      return result;
    }
    for (SObject row : querySystemModeWithBinds(
      'SELECT '
      + parentField
      + ' FROM CKR_ChecklistGateRule__c WHERE '
      + parentField
      + ' IN :parentIds AND Id IN (SELECT CKR_GateRule__c FROM CKR_GateBypassEvent__c) GROUP BY '
      + parentField,
      new Map<String, Object>{ 'parentIds' => parentIds }
    )) {
      result.add((Id) row.get(resultField));
    }
    return result;
  }

  /**
   * Identifies items whose lookup is referenced by audit history.
   * @param itemIds item IDs considered for deletion
   * @return item IDs with audit events
   */
  public Set<Id> selectAuditedItemIds(Set<Id> itemIds) {
    Set<Id> result = new Set<Id>();
    if (itemIds.isEmpty()) {
      return result;
    }
    for (SObject row : querySystemModeWithBinds(
      'SELECT CKR_ChecklistInstanceItem__c FROM CKR_ChecklistAuditEvent__c WHERE CKR_ChecklistInstanceItem__c IN :itemIds GROUP BY CKR_ChecklistInstanceItem__c',
      new Map<String, Object>{ 'itemIds' => itemIds }
    )) {
      result.add((Id) row.get('CKR_ChecklistInstanceItem__c'));
    }
    return result;
  }

  /**
   * Identifies instances whose deletion would cascade to audit history.
   * @param instanceIds checklist instance IDs
   * @return instance IDs with audit events
   */
  public Set<Id> selectAuditedInstanceIds(Set<Id> instanceIds) {
    Set<Id> result = new Set<Id>();
    if (instanceIds.isEmpty()) {
      return result;
    }
    for (SObject row : querySystemModeWithBinds(
      'SELECT CKR_ChecklistInstance__c FROM CKR_ChecklistAuditEvent__c WHERE CKR_ChecklistInstance__c IN :instanceIds GROUP BY CKR_ChecklistInstance__c',
      new Map<String, Object>{ 'instanceIds' => instanceIds }
    )) {
      result.add((Id) row.get('CKR_ChecklistInstance__c'));
    }
    return result;
  }
}
