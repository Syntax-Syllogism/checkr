/**
 * Request DTO passed from trigger gateway code into checklist gate evaluation.
 */
public class CKR_ChecklistGateRequest {
  public Id recordId;
  public String objectApiName;
  public SObject oldRecord;
  public SObject newRecord;
  public Id runningUserId;
}
