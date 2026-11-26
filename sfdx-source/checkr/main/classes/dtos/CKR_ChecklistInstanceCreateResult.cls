/**
 * Response DTO for checklist instance creation attempts.
 */
public class CKR_ChecklistInstanceCreateResult {
  @AuraEnabled
  public Id checklistInstanceId;
  @AuraEnabled
  public Boolean success;
  @AuraEnabled
  public List<String> messages;

  /**
   * Initializes the creation result as unsuccessful with an empty message list.
   */
  public CKR_ChecklistInstanceCreateResult() {
    this.success = false;
    this.messages = new List<String>();
  }
}
