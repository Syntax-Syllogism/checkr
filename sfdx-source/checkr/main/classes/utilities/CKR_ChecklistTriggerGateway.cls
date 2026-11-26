/**
 * Thin trigger entry point that converts object trigger context into gate requests.
 */
public inherited sharing class CKR_ChecklistTriggerGateway {
  private static CKR_IChecklistGateService gateService() {
    return (CKR_IChecklistGateService) CKR_AppFactory.getInstance(
      CKR_IChecklistGateService.class
    );
  }

  /**
   * Evaluates before-save checklist gates and applies record errors for blocked records.
   *
   * @param objectApiName API name for the triggering parent object
   * @param oldMap old trigger records, or null for insert contexts
   * @param newMap new trigger records to evaluate and mark with errors
   */
  public static void handleBefore(
    String objectApiName,
    Map<Id, SObject> oldMap,
    Map<Id, SObject> newMap
  ) {
    if (String.isBlank(objectApiName) || newMap == null || newMap.isEmpty()) {
      return;
    }

    List<CKR_ChecklistGateRequest> requests =
      buildRequests(objectApiName, oldMap, newMap);
    applyErrors(newMap, indexResults(gateService().evaluate(requests)));
  }

  private static List<CKR_ChecklistGateRequest> buildRequests(
    String objectApiName,
    Map<Id, SObject> oldMap,
    Map<Id, SObject> newMap
  ) {
    List<CKR_ChecklistGateRequest> requests =
      new List<CKR_ChecklistGateRequest>();
    for (Id recordId : newMap.keySet()) {
      CKR_ChecklistGateRequest request = new CKR_ChecklistGateRequest();
      request.recordId = recordId;
      request.objectApiName = objectApiName;
      request.oldRecord = oldMap == null ? null : oldMap.get(recordId);
      request.newRecord = newMap.get(recordId);
      request.runningUserId = UserInfo.getUserId();
      requests.add(request);
    }

    return requests;
  }

  private static Map<Id, CKR_ChecklistGateResult> indexResults(
    List<CKR_ChecklistGateResult> results
  ) {
    Map<Id, CKR_ChecklistGateResult> resultsByRecordId =
      new Map<Id, CKR_ChecklistGateResult>();
    for (CKR_ChecklistGateResult result : results) {
      if (result != null && result.recordId != null) {
        resultsByRecordId.put(result.recordId, result);
      }
    }

    return resultsByRecordId;
  }

  private static void applyErrors(
    Map<Id, SObject> newMap,
    Map<Id, CKR_ChecklistGateResult> resultsByRecordId
  ) {
    for (Id recordId : newMap.keySet()) {
      CKR_ChecklistGateResult result = resultsByRecordId.get(recordId);
      if (result != null && result.allowed == false) {
        newMap.get(recordId)
          .addError(
            String.isBlank(result.errorMessage)
            ? 'Checklist gate requirements are not satisfied.'
            : result.errorMessage
          );
      }
    }
  }
}
