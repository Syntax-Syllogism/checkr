/**
 * Evaluates checklist gates for any user who edits a gated parent record, so it
 * stays inherited sharing and only reads through the system-mode gate selectors.
 * See docs/architecture.md.
 */
public inherited sharing class CKR_DefaultChecklistGateService
  extends CKR_ServiceBase implements CKR_IChecklistGateService {
  /**
   * Evaluates gate requests in input order and records any audited bypasses.
   * @param requests candidate parent record changes
   * @return blocked results, including any allowed through audited bypass
   */
  public List<CKR_ChecklistGateResult> evaluate(
    List<CKR_ChecklistGateRequest> requests
  ) {
    List<CKR_ChecklistGateResult> results = new List<CKR_ChecklistGateResult>();
    if (requests == null || requests.isEmpty()) {
      return results;
    }

    Set<String> objectApiNames = collectObjectApiNames(requests);

    Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig> configsByObjectApiName =
      supportedObjectSelector().selectActiveByObjectApiName(objectApiNames);

    Map<String, List<CKR_ChecklistGateRule__c>> gateRulesByObjectApiName =
      checklistGateSelector()
        .selectActivePublishedGateRulesByObjectApiName(objectApiNames);
    Map<Id, Map<Id, CKR_ChecklistInstance__c>> instancesByRecordId =
      selectInstances(requests, gateRulesByObjectApiName);

    for (CKR_ChecklistGateRequest request : requests) {
      List<CKR_ChecklistGateRule__c> rules =
        eligibleRules(
          request,
          configsByObjectApiName,
          gateRulesByObjectApiName
        );
      if (rules == null) {
        continue;
      }
      CKR_ChecklistGateResult blocked =
        CKR_GateRuleEvaluator.firstBlockingResult(
          request,
          rules,
          instancesByRecordId.get(request.recordId)
        );
      if (blocked != null) {
        results.add(blocked);
      }
    }

    applyBypass(results);
    return results;
  }

  private static List<CKR_ChecklistGateRule__c> eligibleRules(
    CKR_ChecklistGateRequest request,
    Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig> configsByObject,
    Map<String, List<CKR_ChecklistGateRule__c>> rulesByObject
  ) {
    if (request == null || String.isBlank(request.objectApiName)) {
      return null;
    }
    CKR_SupportedObjectSelector.SupportedObjectConfig config =
      configsByObject.get(request.objectApiName);
    if (config == null || !config.supportsGates) {
      return null;
    }
    return rulesByObject.get(request.objectApiName);
  }

  private void applyBypass(List<CKR_ChecklistGateResult> results) {
    if (results.isEmpty()) {
      return;
    }
    String source =
      (
        (CKR_IGateBypass) CKR_AppFactory.getInstance(CKR_IGateBypass.class)
      ).source();
    if (source == null) {
      return;
    }
    List<SObject> events = new List<SObject>();
    for (CKR_ChecklistGateResult result : results) {
      if (result.allowed) {
        continue;
      }
      events.add(
        new CKR_GateBypassEvent__c(
          CKR_Actor__c = UserInfo.getUserId(),
          CKR_RecordId__c = String.valueOf(result.recordId),
          CKR_ObjectApiName__c =
            result.recordId.getSObjectType().getDescribe().getName(),
          CKR_GateRule__c = result.gateRuleId,
          CKR_Source__c = source,
          CKR_OccurredOn__c = System.now(),
          CKR_Details__c = result.errorMessage
        )
      );
      result.allowed = true;
    }
    // A failed audit must fail the save as well; never allow an unaudited bypass.
    if (!events.isEmpty()) {
      systemDmlGateway().doInsert(events, CKR_DmlMode.ALL_OR_NONE);
    }
  }

  private Map<Id, Map<Id, CKR_ChecklistInstance__c>> selectInstances(
    List<CKR_ChecklistGateRequest> requests,
    Map<String, List<CKR_ChecklistGateRule__c>> rulesByObject
  ) {
    Set<Id> recordIds = new Set<Id>();
    Set<Id> templateIds = new Set<Id>();
    for (CKR_ChecklistGateRequest request : requests) {
      if (request != null && request.recordId != null) {
        recordIds.add(request.recordId);
      }
    }
    for (List<CKR_ChecklistGateRule__c> rules : rulesByObject.values()) {
      for (CKR_ChecklistGateRule__c rule : rules) {
        templateIds.add(
          rule.CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__c
        );
      }
    }
    Map<Id, Map<Id, CKR_ChecklistInstance__c>> result =
      new Map<Id, Map<Id, CKR_ChecklistInstance__c>>();
    for (CKR_ChecklistInstance__c instance : checklistGateSelector()
      .selectInstancesByRecordId(recordIds, templateIds)) {
      Id recordId = (Id) instance.CKR_ParentRecordId__c;
      if (!result.containsKey(recordId)) {
        result.put(recordId, new Map<Id, CKR_ChecklistInstance__c>());
      }
      result.get(recordId).put(instance.CKR_ChecklistTemplate__c, instance);
    }
    return result;
  }

  private static Set<String> collectObjectApiNames(
    List<CKR_ChecklistGateRequest> requests
  ) {
    Set<String> objectApiNames = new Set<String>();
    for (CKR_ChecklistGateRequest request : requests) {
      if (request != null && !String.isBlank(request.objectApiName)) {
        objectApiNames.add(request.objectApiName);
      }
    }
    return objectApiNames;
  }
}
