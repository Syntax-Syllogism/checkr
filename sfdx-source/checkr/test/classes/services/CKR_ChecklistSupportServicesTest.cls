@IsTest
private class CKR_ChecklistSupportServicesTest {
  @IsTest
  static void supportedObjectSelector_returnsConfiguredAccount() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig> configs =
        CKR_SupportedObjectSelector.selectActiveByObjectApiName(
          new Set<String>{ 'Account' }
        );

      System.Assert.isTrue(
          configs.containsKey('Account'),
          'The supported-object selector should return the Account metadata fixture.'
        );
      CKR_SupportedObjectSelector.SupportedObjectConfig accountConfig =
        configs.get('Account');
      System.Assert.areEqual(
          'Account',
          accountConfig.objectApiName,
          'The Account supported-object config should preserve the object API name.'
        );
      System.Assert.areEqual(
          'Account',
          accountConfig.objectLabel,
          'The Account supported-object config should preserve the object label.'
        );
      System.Assert.isTrue(
          accountConfig.supportsGates,
          'The Account supported-object config should indicate that gates are supported.'
        );
    }
  }

  @IsTest
  static void defaultGateService_handlesSupportedAndUnsupportedObjects() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      List<CKR_ChecklistGateRequest> requests =
        new List<CKR_ChecklistGateRequest>();

      CKR_ChecklistGateRequest accountRequest = new CKR_ChecklistGateRequest();
      accountRequest.objectApiName = 'Account';
      accountRequest.recordId = CKR_TestRecords.fakeId(Account.SObjectType, 1);
      requests.add(accountRequest);

      CKR_ChecklistGateRequest unsupportedRequest =
        new CKR_ChecklistGateRequest();
      unsupportedRequest.objectApiName = 'Opportunity';
      unsupportedRequest.recordId =
        CKR_TestRecords.fakeId(Opportunity.SObjectType, 1);
      requests.add(unsupportedRequest);

      List<CKR_ChecklistGateResult> results =
        new CKR_DefaultChecklistGateService().evaluate(requests);

      System.Assert.isNotNull(
          results,
          'Gate service should always return a non-null result list.'
        );
      System.Assert.areEqual(
          0,
          results.size(),
          'Unsupported objects should not produce gate results.'
        );
    }
  }

  @IsTest
  static void defaultGateService_handlesEmptyAndBlankRequests() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_DefaultChecklistGateService service =
        new CKR_DefaultChecklistGateService();

      System.Assert.areEqual(
          0,
          service.evaluate(null).size(),
          'Null request lists should produce no gate results.'
        );
      System.Assert.areEqual(
          0,
          service.evaluate(new List<CKR_ChecklistGateRequest>()).size(),
          'Empty request lists should produce no gate results.'
        );

      CKR_ChecklistGateRequest blankRequest = new CKR_ChecklistGateRequest();
      blankRequest.objectApiName = '';

      System.Assert.areEqual(
          0,
          service.evaluate(new List<CKR_ChecklistGateRequest>{ blankRequest })
            .size(),
          'Blank object API names should produce no gate results.'
        );
    }
  }

  @IsTest
  static void auditService_writesThroughSystemDmlGateway() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_Mocks.MethodRecorder systemDml = new CKR_Mocks.MethodRecorder();
      CKR_Mocks.MethodRecorder userDml = new CKR_Mocks.MethodRecorder();
      CKR_AppFactory.setMock(
        CKR_ISystemDmlGateway.class,
        CKR_Mocks.stub(CKR_ISystemDmlGateway.class, systemDml)
      );
      CKR_AppFactory.setMock(
        CKR_IDmlGateway.class,
        CKR_Mocks.stub(CKR_IDmlGateway.class, userDml)
      );

      try {
        new CKR_DefaultChecklistAuditService().record(
          new List<CKR_ChecklistAuditEvent__c>{
            new CKR_ChecklistAuditEvent__c(
              CKR_ChecklistInstance__c =
                CKR_TestRecords.fakeId(CKR_ChecklistInstance__c.SObjectType, 1),
              CKR_EventType__c = 'AnswerChanged'
            )
          }
        );

        System.Assert.areEqual(
            1,
            systemDml.callCount('doInsert'),
            'Audit events should be written through the system-mode gateway.'
          );
        System.Assert.areEqual(
            CKR_DmlMode.ALL_OR_NONE,
            systemDml.lastArguments('doInsert')[1],
            'Audit writes should be all-or-none.'
          );
        System.Assert.areEqual(
            0,
            userDml.callCount('doInsert'),
            'Audit events must not be written in user mode.'
          );
      } finally {
        CKR_AppFactory.clearMocks();
      }
    }
  }

  @IsTest
  static void gateResultBlocked_buildsExpectedResult() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_ChecklistGateResult result =
        CKR_ChecklistGateResult.blocked(
          CKR_TestRecords.fakeId(Account.SObjectType, 1),
          'Blocked'
        );

      System.Assert.isFalse(
          result.allowed,
          'Blocked result helpers should mark results as not allowed.'
        );
      System.Assert.areEqual(
          'Blocked',
          result.errorMessage,
          'Blocked result helpers should preserve the provided error message.'
        );
      System.Assert.areEqual(
          CKR_TestRecords.fakeId(Account.SObjectType, 1),
          result.recordId,
          'Blocked result helpers should preserve the provided record id.'
        );
    }
  }

  @IsTest
  static void requestAndResultDtos_initializeAsExpected() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_ChecklistGateRequest gateRequest = new CKR_ChecklistGateRequest();
      gateRequest.recordId = CKR_TestRecords.fakeId(Account.SObjectType, 1);
      gateRequest.objectApiName = 'Account';
      gateRequest.runningUserId = UserInfo.getUserId();

      System.Assert.areEqual(
          CKR_TestRecords.fakeId(Account.SObjectType, 1),
          gateRequest.recordId,
          'Gate request DTO should preserve the assigned record id.'
        );
      System.Assert.areEqual(
          'Account',
          gateRequest.objectApiName,
          'Gate request DTO should preserve the assigned object API name.'
        );
      System.Assert.areEqual(
          UserInfo.getUserId(),
          gateRequest.runningUserId,
          'Gate request DTO should preserve the assigned running user id.'
        );

      CKR_ChecklistInstanceCreateRequest createRequest =
        new CKR_ChecklistInstanceCreateRequest();
      createRequest.templateId =
        CKR_TestRecords.fakeId(CKR_ChecklistTemplate__c.SObjectType, 1);
      createRequest.templateVersionId =
        CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 1);
      createRequest.parentRecordId =
        CKR_TestRecords.fakeId(Account.SObjectType, 1);
      createRequest.parentObjectApiName = 'Account';
      createRequest.dueDate = Date.today();

      System.Assert.areEqual(
          CKR_TestRecords.fakeId(CKR_ChecklistTemplate__c.SObjectType, 1),
          createRequest.templateId,
          'Create request DTO should preserve the assigned template id.'
        );
      System.Assert.areEqual(
          CKR_TestRecords.fakeId(
            CKR_ChecklistTemplateVersion__c.SObjectType,
            1
          ),
          createRequest.templateVersionId,
          'Create request DTO should preserve the assigned template version id.'
        );
      System.Assert.areEqual(
          CKR_TestRecords.fakeId(Account.SObjectType, 1),
          createRequest.parentRecordId,
          'Create request DTO should preserve the assigned parent record id.'
        );
      System.Assert.areEqual(
          'Account',
          createRequest.parentObjectApiName,
          'Create request DTO should preserve the assigned parent object API name.'
        );
      System.Assert.areEqual(
          Date.today(),
          createRequest.dueDate,
          'Create request DTO should preserve the assigned due date.'
        );
    }
  }

  @IsTest
  static void viewerAndInstanceService_returnStarterResponses() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_ChecklistViewerController.ChecklistViewerResponse viewerResponse =
        CKR_ChecklistViewerController.getRecordChecklists(
          CKR_TestRecords.fakeId(Account.SObjectType, 1)
        );

      System.Assert.areEqual(
          String.valueOf(CKR_TestRecords.fakeId(Account.SObjectType, 1)),
          viewerResponse.recordId,
          'Viewer response DTO should echo the requested record id.'
        );
      System.Assert.areEqual(
          0,
          viewerResponse.checklists.size(),
          'Viewer response should be empty when no checklist instances are returned.'
        );

      CKR_ChecklistInstanceCreateRequest request =
        new CKR_ChecklistInstanceCreateRequest();
      request.parentRecordId = CKR_TestRecords.fakeId(Account.SObjectType, 1);
      request.parentObjectApiName = 'Account';

      CKR_ChecklistInstanceCreateResult result =
        new CKR_DefaultChecklistInstanceService().createFromTemplate(request);

      System.Assert.isFalse(
          result.success,
          'Instance service should reject requests that omit both template and version ids.'
        );
      System.Assert.isTrue(
          result.messages.size() > 0,
          'Rejected requests should include at least one validation message.'
        );
    }
  }

  @IsTest
  static void supportedObjectSelector_handlesEmptyInput() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      System.Assert.areEqual(
          0,
          CKR_SupportedObjectSelector.selectActiveByObjectApiName(
              new Set<String>()
            )
            .size(),
          'The supported-object selector should return an empty result for an empty input set.'
        );
    }
  }
}
