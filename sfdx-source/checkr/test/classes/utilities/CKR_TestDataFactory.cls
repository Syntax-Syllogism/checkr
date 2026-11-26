@IsTest
public class CKR_TestDataFactory {
  /**
   * Identifies an Account template and its first version.
   */
  public class TemplateFixture {
    public Id templateId;
    public Id versionId;
  }

  /**
   * Identifies the inserted Account, template, version, and checklist instance.
   */
  public class ChecklistInstanceFixture {
    public Id accountId;
    public Id templateId;
    public Id versionId;
    public Id instanceId;
  }

  /**
   * Names and rollup values for an Account checklist fixture.
   */
  public class ChecklistInstanceSpec {
    public String accountName;
    public String templateName;
    public Date dueDate;
    public Integer requiredItemCount;
    public Integer completedRequiredItemCount;
    public Boolean isComplete;
    public Boolean isOverdue;
    public Decimal percentComplete;
  }

  /**
   * Inserts an Account template and its first draft version.
   * @param templateName name to assign to the fixture template
   * @return IDs of the template and draft version
   */
  public static TemplateFixture createDraftAccountTemplate(
    String templateName
  ) {
    CKR_ChecklistTemplate__c templateRecord =
      new CKR_ChecklistTemplate__c(
        Name = templateName,
        CKR_DeveloperName__c = templateName.replace(' ', '_'),
        CKR_SupportedObjectDeveloperName__c = 'Account',
        CKR_TargetObjectApiName__c = 'Account',
        CKR_Active__c = true
      );
    insert templateRecord;

    CKR_ChecklistTemplateVersion__c versionRecord =
      new CKR_ChecklistTemplateVersion__c(
        CKR_ChecklistTemplate__c = templateRecord.Id,
        CKR_Status__c = 'Draft',
        CKR_VersionNumber__c = 1,
        CKR_CompletionAccessMode__c = 'ReadAccess'
      );
    insert versionRecord;

    TemplateFixture fixture = new TemplateFixture();
    fixture.templateId = templateRecord.Id;
    fixture.versionId = versionRecord.Id;
    return fixture;
  }

  /**
   * Inserts an Account template, populates its draft, and publishes it.
   * @param templateName name to assign to the fixture template
   * @return IDs of the template and published version
   */
  public static TemplateFixture createPublishedAccountTemplate(
    String templateName
  ) {
    TemplateFixture fixture = createDraftAccountTemplate(templateName);
    addAccountTemplateItems(fixture.versionId);
    publishTemplateVersion(fixture.templateId, fixture.versionId);
    return fixture;
  }

  /**
   * Adds a required text item and optional picklist item to a draft.
   * @param versionId checklist template version ID
   */
  public static void addAccountTemplateItems(Id versionId) {
    insert new List<CKR_ChecklistTemplateItem__c>{
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c = versionId,
        CKR_Label__c = 'Confirm billing contact',
        CKR_ExplanationInputType__c = 'Text',
        CKR_Required__c = true,
        CKR_SortOrder__c = 1
      ),
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c = versionId,
        CKR_Label__c = 'Risk review outcome',
        CKR_ExplanationInputType__c = 'Picklist',
        CKR_ExplanationPicklistValues__c = 'Approved;Needs Review',
        CKR_Required__c = false,
        CKR_SortOrder__c = 2
      )
    };
  }

  /**
   * Publishes a fixture version through the same service as the application.
   * @param templateId checklist template ID
   * @param versionId checklist template version ID
   */
  public static void publishTemplateVersion(Id templateId, Id versionId) {
    (
      (CKR_IChecklistTemplateVersionService) CKR_AppFactory.getInstance(
        CKR_IChecklistTemplateVersionService.class
      )
    ).publish(versionId);
  }

  /**
   * Creates the Account, published checklist template, and preconfigured instance.
   * @param spec names and initial instance state
   * @return IDs of the inserted fixtures
   */
  public static ChecklistInstanceFixture createAccountChecklistInstance(
    ChecklistInstanceSpec spec
  ) {
    Account account = new Account(Name = spec.accountName);
    insert account;

    TemplateFixture templateFixture =
      createPublishedAccountTemplate(spec.templateName);

    CKR_ChecklistInstance__c instanceRecord =
      new CKR_ChecklistInstance__c(
        CKR_ChecklistTemplate__c = templateFixture.templateId,
        CKR_ChecklistTemplateVersion__c = templateFixture.versionId,
        CKR_ParentRecordId__c = account.Id,
        CKR_ParentObjectApiName__c = 'Account',
        CKR_DueDate__c = spec.dueDate,
        CKR_RequiredItemCount__c = spec.requiredItemCount,
        CKR_CompletedRequiredItemCount__c = spec.completedRequiredItemCount,
        CKR_IsComplete__c = spec.isComplete,
        CKR_IsOverdue__c = spec.isOverdue,
        CKR_PercentComplete__c = spec.percentComplete
      );
    insert instanceRecord;

    ChecklistInstanceFixture fixture = new ChecklistInstanceFixture();
    fixture.accountId = account.Id;
    fixture.templateId = templateFixture.templateId;
    fixture.versionId = templateFixture.versionId;
    fixture.instanceId = instanceRecord.Id;
    return fixture;
  }
}
