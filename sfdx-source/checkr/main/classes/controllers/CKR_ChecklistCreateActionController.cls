/**
 * Exposes the template picker and checklist creation action to Lightning.
 */
public with sharing class CKR_ChecklistCreateActionController {
  /**
   * Summarizes one published template available in the create action.
   */
  public class ChecklistTemplateOption {
    @AuraEnabled
    public String templateId;
    @AuraEnabled
    public String templateVersionId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Decimal versionNumber;
  }

  /**
   * Returns the parent record context and templates that can be selected.
   */
  public class ChecklistCreateContextResponse {
    @AuraEnabled
    public String recordId;
    @AuraEnabled
    public String objectApiName;
    @AuraEnabled
    public List<ChecklistTemplateOption> templates =
      new List<ChecklistTemplateOption>();
  }

  private static CKR_ISupportedObjectSelector supportedObjectSelector() {
    return (CKR_ISupportedObjectSelector) CKR_AppFactory.getInstance(
      CKR_ISupportedObjectSelector.class
    );
  }

  private static CKR_IChecklistCreateContextSelector createContextSelector() {
    return (CKR_IChecklistCreateContextSelector) CKR_AppFactory.getInstance(
      CKR_IChecklistCreateContextSelector.class
    );
  }

  private static CKR_IChecklistInstanceService instanceService() {
    return (CKR_IChecklistInstanceService) CKR_AppFactory.getInstance(
      CKR_IChecklistInstanceService.class
    );
  }

  /**
   * Loads the record context and any published templates available for its object.
   * @param recordId parent record ID
   * @param objectApiName API name of the parent Salesforce object
   * @return context and templates for the Lightning create action
   */
  @AuraEnabled(cacheable=true)
  public static ChecklistCreateContextResponse getCreateContext(
    Id recordId,
    String objectApiName
  ) {
    ChecklistCreateContextResponse response =
      new ChecklistCreateContextResponse();
    response.recordId = recordId == null ? null : String.valueOf(recordId);
    response.objectApiName = objectApiName;

    if (String.isBlank(objectApiName)) {
      return response;
    }

    Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig> supportedObjects =
      supportedObjectSelector()
        .selectActiveByObjectApiName(new Set<String>{ objectApiName });
    if (!supportedObjects.containsKey(objectApiName)) {
      return response;
    }

    for (CKR_ChecklistTemplate__c templateRecord : createContextSelector()
      .selectAvailableTemplatesForObject(objectApiName)) {
      response.templates.add(toTemplateOption(templateRecord));
    }

    return response;
  }

  /**
   * Creates a checklist from the selections in the Lightning create action.
   * @param request request from the caller
   * @return creation outcome and messages
   */
  @AuraEnabled
  public static CKR_ChecklistInstanceCreateResult createChecklistAction(
    CKR_ChecklistInstanceCreateRequest request
  ) {
    return createChecklist(request);
  }

  /**
   * Delegates snapshot creation to the configured instance service.
   * @param request request from the caller
   * @return creation outcome and messages
   */
  public static CKR_ChecklistInstanceCreateResult createChecklist(
    CKR_ChecklistInstanceCreateRequest request
  ) {
    return instanceService().createFromTemplate(request);
  }

  private static ChecklistTemplateOption toTemplateOption(
    CKR_ChecklistTemplate__c templateRecord
  ) {
    ChecklistTemplateOption option = new ChecklistTemplateOption();
    option.templateId = String.valueOf(templateRecord.Id);
    option.templateVersionId =
      String.valueOf(templateRecord.CKR_CurrentPublishedVersion__c);
    option.name = templateRecord.Name;
    option.description =
      String.isBlank(
        templateRecord.CKR_CurrentPublishedVersion__r.CKR_Description__c
      )
      ? templateRecord.CKR_Description__c
      : templateRecord.CKR_CurrentPublishedVersion__r.CKR_Description__c;
    option.versionNumber =
      templateRecord.CKR_CurrentPublishedVersion__r.CKR_VersionNumber__c;
    return option;
  }
}
