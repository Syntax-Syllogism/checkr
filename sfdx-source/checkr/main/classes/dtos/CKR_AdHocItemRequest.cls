/**
 * Captures editable metadata for a new ad hoc checklist item.
 */
public class CKR_AdHocItemRequest {
  @AuraEnabled
  public Id checklistInstanceId;
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
