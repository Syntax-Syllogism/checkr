/**
 * Result DTO returned by gate evaluation for records that may need blocking errors.
 */
public class CKR_ChecklistGateResult {
  public Id recordId;
  public Boolean allowed = true;
  public String errorMessage;
  public Id checklistInstanceId;
  public Id gateRuleId;
  public String gateRuleName;

  /**
   * Creates a blocked gate result for a parent record.
   *
   * @param recordId parent record that failed gate evaluation
   * @param errorMessage message to surface on the blocked record
   * @return result marked as not allowed
   */
  public static CKR_ChecklistGateResult blocked(
    Id recordId,
    String errorMessage
  ) {
    CKR_ChecklistGateResult result = new CKR_ChecklistGateResult();
    result.recordId = recordId;
    result.allowed = false;
    result.errorMessage = errorMessage;
    return result;
  }
}
