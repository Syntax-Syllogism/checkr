/**
 * Applies loaded gate rules to a change and its existing checklist snapshots.
 */
public inherited sharing class CKR_GateRuleEvaluator {
  /**
   * Returns the first rule that blocks a request in selector order.
   * @param request parent record change
   * @param rules gate rules for the parent object
   * @param instances checklist instances for the parent, keyed by template ID
   * @return blocking result, or null when every gate is satisfied
   */
  public static CKR_ChecklistGateResult firstBlockingResult(
    CKR_ChecklistGateRequest request,
    List<CKR_ChecklistGateRule__c> rules,
    Map<Id, CKR_ChecklistInstance__c> instances
  ) {
    if (rules == null) {
      return null;
    }
    for (CKR_ChecklistGateRule__c rule : rules) {
      if (
        gateRuleMatchesRequest(rule, request)
        && requiresCompletion(rule, instances)
      ) {
        return buildBlockedResult(request, rule);
      }
    }
    return null;
  }

  private static Boolean requiresCompletion(
    CKR_ChecklistGateRule__c rule,
    Map<Id, CKR_ChecklistInstance__c> instances
  ) {
    Id templateId =
      rule.CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__c;
    CKR_ChecklistInstance__c instance =
      instances == null ? null : instances.get(templateId);
    if (instance == null) {
      return rule.CKR_ChecklistTemplateVersion__r.CKR_Status__c == 'Published';
    }
    return instance.CKR_ChecklistTemplateVersion__c
        == rule.CKR_ChecklistTemplateVersion__c
      && instance.CKR_IsComplete__c != true;
  }

  private static Boolean gateRuleMatchesRequest(
    CKR_ChecklistGateRule__c gateRule,
    CKR_ChecklistGateRequest request
  ) {
    if (gateRule == null || request == null || request.newRecord == null) {
      return false;
    }

    String fieldApiName = gateRule.CKR_TargetFieldApiName__c;
    if (String.isBlank(fieldApiName)) {
      return false;
    }

    Object newValue = request.newRecord.get(fieldApiName);
    Object oldValue =
      request.oldRecord == null ? null : request.oldRecord.get(fieldApiName);
    String newValueString = normalizeValue(newValue);
    String oldValueString = normalizeValue(oldValue);

    if (newValueString == oldValueString) {
      return false;
    }

    if (gateRule.CKR_ProtectedActionType__c == 'AnyFieldValueChange') {
      return true;
    }

    if (gateRule.CKR_ProtectedActionType__c != 'SpecificFieldValueChange') {
      return false;
    }

    return collectTargetValues(gateRule).contains(newValueString);
  }

  private static String normalizeValue(Object value) {
    return value == null ? null : String.valueOf(value);
  }

  private static Set<String> collectTargetValues(
    CKR_ChecklistGateRule__c gateRule
  ) {
    Set<String> targetValues = new Set<String>();
    if (!String.isBlank(gateRule.CKR_TargetValue__c)) {
      targetValues.add(gateRule.CKR_TargetValue__c.trim());
    }

    if (!String.isBlank(gateRule.CKR_TargetValueSet__c)) {
      for (String targetValue : gateRule.CKR_TargetValueSet__c.split(
          '[;,\\n]+'
        )) {
        if (!String.isBlank(targetValue)) {
          targetValues.add(targetValue.trim());
        }
      }
    }

    return targetValues;
  }

  private static CKR_ChecklistGateResult buildBlockedResult(
    CKR_ChecklistGateRequest request,
    CKR_ChecklistGateRule__c gateRule
  ) {
    CKR_ChecklistGateResult result =
      CKR_ChecklistGateResult.blocked(
        request.recordId,
        String.isBlank(gateRule.CKR_ErrorMessage__c)
        ? 'Checklist gate requirements are not satisfied.'
        : gateRule.CKR_ErrorMessage__c
      );
    result.checklistInstanceId = null;
    result.gateRuleId = gateRule.Id;
    result.gateRuleName = gateRule.Name;
    return result;
  }
}
