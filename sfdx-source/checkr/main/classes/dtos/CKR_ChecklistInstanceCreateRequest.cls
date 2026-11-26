/**
 * Request DTO for creating a checklist instance from a template or template version.
 */
public class CKR_ChecklistInstanceCreateRequest {
  @AuraEnabled
  public Id templateId;
  @AuraEnabled
  public Id templateVersionId;
  @AuraEnabled
  public Id parentRecordId;
  @AuraEnabled
  public String parentObjectApiName;
  @AuraEnabled
  public Date dueDate;
}
