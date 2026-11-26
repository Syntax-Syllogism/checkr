/**
 * Evaluation contract for changes to checklist-gated Salesforce records.
 */
public interface CKR_IChecklistGateService {
  /**
   * Checks changes for blocking rules and records eligible audited bypasses.
   * @param requests parent record changes to evaluate
   * @return gate failures and their final allow or block decisions
   */
  List<CKR_ChecklistGateResult> evaluate(
    List<CKR_ChecklistGateRequest> requests
  );
}
