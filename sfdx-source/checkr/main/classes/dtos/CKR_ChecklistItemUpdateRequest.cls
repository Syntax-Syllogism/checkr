/**
 * Edits a checklist answer, assignee, and editable ad hoc metadata.
 */
public class CKR_ChecklistItemUpdateRequest {
  @AuraEnabled
  public Id checklistItemId;
  @AuraEnabled
  public Boolean checkboxValue;
  @AuraEnabled
  public String explanation;
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String explanationInputType;
  @AuraEnabled
  public String explanationPicklistValues;
  @AuraEnabled
  public Boolean explanationRequired;
  @AuraEnabled
  public Id assigneeUserId;
}
