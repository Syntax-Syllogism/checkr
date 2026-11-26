// In-memory unit tests exercise logic and stubbed dependencies without database access.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_ChecklistCreateActionControllerTest {
  @IsTest
  static void getCreateContext_returnsPublishedTemplates() {
    Id templateId =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplate__c.SObjectType, 1);
    Id versionId =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 1);

    CKR_SupportedObjectSelector.SupportedObjectConfig accountConfig =
      new CKR_SupportedObjectSelector.SupportedObjectConfig();
    accountConfig.objectApiName = 'Account';
    accountConfig.supportsGates = true;

    CKR_Mocks.MethodRecorder supported =
      new CKR_Mocks.MethodRecorder().when(
        'selectActiveByObjectApiName',
        new Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig>{
          'Account' => accountConfig
        }
      );
    CKR_Mocks.MethodRecorder context =
      new CKR_Mocks.MethodRecorder().when(
        'selectAvailableTemplatesForObject',
        new List<CKR_ChecklistTemplate__c>{
          (CKR_ChecklistTemplate__c) CKR_TestRecords.build(
            CKR_ChecklistTemplate__c.SObjectType,
            new Map<String, Object>{
              'Id' => templateId,
              'Name' => 'Account Launch',
              'CKR_Description__c' => 'Template description',
              'CKR_CurrentPublishedVersion__c' => versionId,
              'CKR_CurrentPublishedVersion__r.CKR_Description__c' => 'Version description',
              'CKR_CurrentPublishedVersion__r.CKR_VersionNumber__c' => 1
            }
          )
        }
      );
    CKR_AppFactory.setMock(
      CKR_ISupportedObjectSelector.class,
      CKR_Mocks.stub(CKR_ISupportedObjectSelector.class, supported)
    );
    CKR_AppFactory.setMock(
      CKR_IChecklistCreateContextSelector.class,
      CKR_Mocks.stub(CKR_IChecklistCreateContextSelector.class, context)
    );

    try {
      Integer queriesBefore = Limits.getQueries();
      CKR_ChecklistCreateActionController.ChecklistCreateContextResponse response =
        CKR_ChecklistCreateActionController.getCreateContext(
          CKR_TestRecords.fakeId(Account.SObjectType, 1),
          'Account'
        );

      System.Assert.areEqual(
          queriesBefore,
          Limits.getQueries(),
          'Stubbed selectors should keep the unit test off the database.'
        );
      System.Assert.areEqual(
          String.valueOf(CKR_TestRecords.fakeId(Account.SObjectType, 1)),
          response.recordId,
          'Create context should echo the current record id.'
        );
      System.Assert.areEqual(
          'Account',
          response.objectApiName,
          'Create context should echo the current object API name.'
        );
      System.Assert.areEqual(
          1,
          response.templates.size(),
          'Supported objects should return one available template in this fixture.'
        );
      System.Assert.areEqual(
          String.valueOf(templateId),
          response.templates[0].templateId,
          'Template id should come from the selector result.'
        );
      System.Assert.areEqual(
          String.valueOf(versionId),
          response.templates[0].templateVersionId,
          'Template version id should come from the current published version.'
        );
      System.Assert.areEqual(
          'Account Launch',
          response.templates[0].name,
          'Template option should expose the template name.'
        );
      System.Assert.areEqual(
          'Version description',
          response.templates[0].description,
          'Version description should override template description when present.'
        );
      System.Assert.areEqual(
          1,
          response.templates[0].versionNumber,
          'Version number should be exposed to the create action.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void getCreateContext_returnsEmptyForUnsupportedObject() {
    CKR_Mocks.MethodRecorder supported =
      new CKR_Mocks.MethodRecorder().when(
        'selectActiveByObjectApiName',
        new Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig>()
      );
    CKR_Mocks.MethodRecorder context = new CKR_Mocks.MethodRecorder();
    CKR_AppFactory.setMock(
      CKR_ISupportedObjectSelector.class,
      CKR_Mocks.stub(CKR_ISupportedObjectSelector.class, supported)
    );
    CKR_AppFactory.setMock(
      CKR_IChecklistCreateContextSelector.class,
      CKR_Mocks.stub(CKR_IChecklistCreateContextSelector.class, context)
    );

    try {
      CKR_ChecklistCreateActionController.ChecklistCreateContextResponse response =
        CKR_ChecklistCreateActionController.getCreateContext(
          CKR_TestRecords.fakeId(Opportunity.SObjectType, 1),
          'Opportunity'
        );

      System.Assert.areEqual(
          'Opportunity',
          response.objectApiName,
          'Unsupported-object responses should still report the requested object.'
        );
      System.Assert.areEqual(
          0,
          response.templates.size(),
          'Unsupported objects should return no template options.'
        );
      System.Assert.areEqual(
          0,
          context.callCount('selectAvailableTemplatesForObject'),
          'Unsupported objects should not query templates.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void createChecklistAction_forwardsTheCompleteRequest() {
    CKR_ChecklistInstanceCreateResult stubbedResult =
      new CKR_ChecklistInstanceCreateResult();
    stubbedResult.success = true;
    stubbedResult.checklistInstanceId =
      CKR_TestRecords.fakeId(CKR_ChecklistInstance__c.SObjectType, 99);
    CKR_Mocks.MethodRecorder service =
      new CKR_Mocks.MethodRecorder().when('createFromTemplate', stubbedResult);
    CKR_AppFactory.setMock(
      CKR_IChecklistInstanceService.class,
      CKR_Mocks.stub(CKR_IChecklistInstanceService.class, service)
    );

    try {
      Id templateId =
        CKR_TestRecords.fakeId(CKR_ChecklistTemplate__c.SObjectType, 5);
      Id parentRecordId = CKR_TestRecords.fakeId(Account.SObjectType, 5);
      Date dueDate = Date.today().addDays(7);

      CKR_ChecklistInstanceCreateRequest actionRequest =
        new CKR_ChecklistInstanceCreateRequest();
      actionRequest.templateId = templateId;
      actionRequest.templateVersionId =
        CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 5);
      actionRequest.parentRecordId = parentRecordId;
      actionRequest.parentObjectApiName = 'Account';
      actionRequest.dueDate = dueDate;
      CKR_ChecklistInstanceCreateResult result =
        CKR_ChecklistCreateActionController.createChecklistAction(
          actionRequest
        );

      System.Assert.isTrue(
          result.success,
          'The stub service should report success to the controller.'
        );
      System.Assert.areEqual(
          1,
          service.callCount('createFromTemplate'),
          'The controller should call the service exactly once.'
        );
      CKR_ChecklistInstanceCreateRequest request =
        (CKR_ChecklistInstanceCreateRequest) service.lastArguments(
          'createFromTemplate'
        )[0];
      System.Assert.areEqual(
          templateId,
          request.templateId,
          'The controller should map template id into the service request.'
        );
      System.Assert.areEqual(
          actionRequest.templateVersionId,
          request.templateVersionId
        );
      System.Assert.areEqual(
          parentRecordId,
          request.parentRecordId,
          'The controller should map the parent record id into the service request.'
        );
      System.Assert.areEqual(
          'Account',
          request.parentObjectApiName,
          'The controller should map the parent object API name into the service request.'
        );
      System.Assert.areEqual(
          dueDate,
          request.dueDate,
          'The controller should preserve the due date.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void createChecklist_blocksDuplicateUniqueKeyWithoutDml() {
    Id templateId =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplate__c.SObjectType, 41);
    CKR_ChecklistTemplateVersion__c templateVersion =
      (CKR_ChecklistTemplateVersion__c) CKR_TestRecords.build(
        CKR_ChecklistTemplateVersion__c.SObjectType,
        new Map<String, Object>{
          'Id' => CKR_TestRecords.fakeId(
            CKR_ChecklistTemplateVersion__c.SObjectType,
            41
          ),
          'CKR_Status__c' => 'Published',
          'CKR_ChecklistTemplate__c' => templateId,
          'CKR_ChecklistTemplate__r.CKR_Active__c' => true,
          'CKR_ChecklistTemplate__r.CKR_TargetObjectApiName__c' => 'Account'
        }
      );
    CKR_Mocks.MethodRecorder selector =
      new CKR_Mocks.MethodRecorder()
        .when('selectCurrentPublishedTemplateVersion', templateVersion)
        .when('existingInstanceExists', true);
    CKR_Mocks.MethodRecorder dml = new CKR_Mocks.MethodRecorder();
    CKR_AppFactory.setMock(
      CKR_IChecklistInstanceSelector.class,
      CKR_Mocks.stub(CKR_IChecklistInstanceSelector.class, selector)
    );
    CKR_AppFactory.setMock(
      CKR_IDmlGateway.class,
      CKR_Mocks.stub(CKR_IDmlGateway.class, dml)
    );

    try {
      CKR_ChecklistInstanceCreateRequest request =
        new CKR_ChecklistInstanceCreateRequest();
      request.templateId = templateId;
      request.parentRecordId = CKR_TestRecords.fakeId(Account.SObjectType, 41);
      request.parentObjectApiName = 'Account';

      CKR_ChecklistInstanceCreateResult result =
        new CKR_DefaultChecklistInstanceService().createFromTemplate(request);

      System.Assert.isFalse(
          result.success,
          'Duplicate unique-key requests should be rejected before any DML occurs.'
        );
      System.Assert.areEqual(
          'A checklist instance already exists for this record and template.',
          result.messages[0],
          'The duplicate guard should return the expected error message.'
        );
      System.Assert.areEqual(
          0,
          dml.callCount('doInsert'),
          'The duplicate guard should not perform any inserts.'
        );
      System.Assert.isFalse(
          (
            (String) selector.lastArguments('existingInstanceExists')[0]
          ).contains('User:'),
          'The generated unique key should not include an assignee segment.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }
}
