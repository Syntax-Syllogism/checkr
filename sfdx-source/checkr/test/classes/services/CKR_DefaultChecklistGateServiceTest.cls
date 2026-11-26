// In-memory unit tests exercise logic and stubbed dependencies without database access.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_DefaultChecklistGateServiceTest {
  @IsTest
  static void anyFieldValueChange_blocksWhenNoCompleteChecklistExists() {
    Id accountId = CKR_TestRecords.fakeId(Account.SObjectType, 1);
    Id versionId =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 1);
    Id gateRuleId =
      CKR_TestRecords.fakeId(CKR_ChecklistGateRule__c.SObjectType, 1);

    installSelectorFakes(
      buildSupportedObjectConfigs(),
      new Map<String, List<CKR_ChecklistGateRule__c>>{
        'Account' => new List<CKR_ChecklistGateRule__c>{
          buildGateRule(
            gateRuleId,
            versionId,
            new Map<String, Object>{
              'CKR_ProtectedActionType__c' => 'AnyFieldValueChange',
              'CKR_TargetFieldApiName__c' => 'Industry',
              'CKR_ErrorMessage__c' => 'Industry changes require a completed checklist.'
            }
          )
        }
      },
      new Map<Id, Set<Id>>()
    );

    try {
      CKR_ChecklistGateRequest request = new CKR_ChecklistGateRequest();
      request.recordId = accountId;
      request.objectApiName = 'Account';
      request.oldRecord = new Account(Id = accountId, Industry = 'Banking');
      request.newRecord = new Account(Id = accountId, Industry = 'Technology');

      List<CKR_ChecklistGateResult> results =
        new CKR_DefaultChecklistGateService().evaluate(
          new List<CKR_ChecklistGateRequest>{ request }
        );

      System.Assert.areEqual(
          1,
          results.size(),
          'AnyFieldValueChange should block when the protected field changes without a completed checklist.'
        );
      System.Assert.isFalse(
          results[0].allowed,
          'Blocked gate results should mark the request as not allowed.'
        );
      System.Assert.areEqual(
          gateRuleId,
          results[0].gateRuleId,
          'Blocked gate results should identify the matching gate rule.'
        );
      System.Assert.areEqual(
          'Industry changes require a completed checklist.',
          results[0].errorMessage,
          'Blocked gate results should preserve the configured error message.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void anyFieldValueChange_allowsWhenCompleteChecklistExists() {
    Id accountId = CKR_TestRecords.fakeId(Account.SObjectType, 2);
    Id versionId =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 2);

    installSelectorFakes(
      buildSupportedObjectConfigs(),
      new Map<String, List<CKR_ChecklistGateRule__c>>{
        'Account' => new List<CKR_ChecklistGateRule__c>{
          buildGateRule(
            CKR_TestRecords.fakeId(CKR_ChecklistGateRule__c.SObjectType, 2),
            versionId,
            new Map<String, Object>{
              'CKR_ProtectedActionType__c' => 'AnyFieldValueChange',
              'CKR_TargetFieldApiName__c' => 'Industry',
              'CKR_ErrorMessage__c' => 'Industry changes require a completed checklist.'
            }
          )
        }
      },
      new Map<Id, Set<Id>>{ accountId => new Set<Id>{ versionId } }
    );

    try {
      CKR_ChecklistGateRequest request = new CKR_ChecklistGateRequest();
      request.recordId = accountId;
      request.objectApiName = 'Account';
      request.oldRecord = new Account(Id = accountId, Industry = 'Banking');
      request.newRecord = new Account(Id = accountId, Industry = 'Technology');

      List<CKR_ChecklistGateResult> results =
        new CKR_DefaultChecklistGateService().evaluate(
          new List<CKR_ChecklistGateRequest>{ request }
        );

      System.Assert.areEqual(
          0,
          results.size(),
          'A completed checklist should satisfy the AnyFieldValueChange gate.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void specificFieldValueChange_onlyBlocksForConfiguredValue() {
    Id accountId = CKR_TestRecords.fakeId(Account.SObjectType, 3);
    Id versionId =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 3);
    Id gateRuleId =
      CKR_TestRecords.fakeId(CKR_ChecklistGateRule__c.SObjectType, 3);

    installSelectorFakes(
      buildSupportedObjectConfigs(),
      new Map<String, List<CKR_ChecklistGateRule__c>>{
        'Account' => new List<CKR_ChecklistGateRule__c>{
          buildGateRule(
            gateRuleId,
            versionId,
            new Map<String, Object>{
              'CKR_ProtectedActionType__c' => 'SpecificFieldValueChange',
              'CKR_TargetFieldApiName__c' => 'Rating',
              'CKR_TargetValue__c' => 'Hot',
              'CKR_TargetValueSet__c' => 'Escalated;Critical',
              'CKR_ErrorMessage__c' => 'Hot rating requires completion.'
            }
          )
        }
      },
      new Map<Id, Set<Id>>()
    );

    try {
      CKR_ChecklistGateRequest blockedRequest = new CKR_ChecklistGateRequest();
      blockedRequest.recordId = accountId;
      blockedRequest.objectApiName = 'Account';
      blockedRequest.oldRecord = new Account(Id = accountId, Rating = 'Warm');
      blockedRequest.newRecord = new Account(Id = accountId, Rating = 'Hot');

      CKR_ChecklistGateRequest allowedRequest = new CKR_ChecklistGateRequest();
      allowedRequest.recordId = accountId;
      allowedRequest.objectApiName = 'Account';
      allowedRequest.oldRecord = new Account(Id = accountId, Rating = 'Warm');
      allowedRequest.newRecord = new Account(Id = accountId, Rating = 'Cold');

      List<CKR_ChecklistGateResult> blockedResults =
        new CKR_DefaultChecklistGateService().evaluate(
          new List<CKR_ChecklistGateRequest>{ blockedRequest }
        );
      List<CKR_ChecklistGateResult> allowedResults =
        new CKR_DefaultChecklistGateService().evaluate(
          new List<CKR_ChecklistGateRequest>{ allowedRequest }
        );

      System.Assert.areEqual(
          1,
          blockedResults.size(),
          'SpecificFieldValueChange should block when the configured target value is selected.'
        );
      System.Assert.areEqual(
          gateRuleId,
          blockedResults[0].gateRuleId,
          'Blocked specific-value gate results should identify the matching gate rule.'
        );
      System.Assert.areEqual(
          'Hot rating requires completion.',
          blockedResults[0].errorMessage,
          'Blocked specific-value gate results should preserve the configured error message.'
        );
      System.Assert.areEqual(
          0,
          allowedResults.size(),
          'SpecificFieldValueChange should allow non-target values.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void permissionBypassAuditsBlockedSave() {
    System.Assert.areEqual(
        1,
        verifyBypassAndCountEvents('CustomPermission', 1, 1)
      );
  }

  @IsTest
  static void settingBypassAuditsBlockedSave() {
    System.Assert.areEqual(
        1,
        verifyBypassAndCountEvents('CustomSetting', 1, 1)
      );
  }

  @IsTest
  static void allowedSaveDoesNotAudit() {
    System.Assert.areEqual(
        0,
        verifyBypassAndCountEvents('CustomPermission', 1, 0)
      );
  }

  @IsTest
  static void bulkBypassAuditsOnly100BlockedRecordsInOneDml() {
    System.Assert.areEqual(
        100,
        verifyBypassAndCountEvents('CustomSetting', 200, 100)
      );
  }

  @IsTest
  static void auditFailureSurfaces() {
    CKR_Mocks.MethodRecorder dml = setupBypass('CustomPermission');
    dml.whenThrow('doInsert', new DmlException('Audit unavailable'));
    try {
      new CKR_DefaultChecklistGateService().evaluate(bypassRequests(1, 1));
      System.Assert.fail('Audit failure must prevent an unaudited bypass.');
    } catch (DmlException ex) {
      System.Assert.areEqual('Audit unavailable', ex.getMessage());
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void evaluationFailureIsNotBypassed() {
    CKR_Mocks.MethodRecorder dml = setupBypass('CustomPermission');
    CKR_AppFactory.setMock(
      CKR_IChecklistGateSelector.class,
      CKR_Mocks.stub(
        CKR_IChecklistGateSelector.class,
        new CKR_Mocks.MethodRecorder().whenThrow(
          'selectActivePublishedGateRulesByObjectApiName',
          new QueryException('Gate unavailable')
        )
      )
    );
    try {
      new CKR_DefaultChecklistGateService().evaluate(bypassRequests(1, 1));
      System.Assert.fail('Bypass must not hide evaluation errors.');
    } catch (QueryException ex) {
      System.Assert.areEqual('Gate unavailable', ex.getMessage());
      System.Assert.areEqual(0, dml.callCount('doInsert'));
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  private static CKR_Mocks.MethodRecorder setupBypass(String source) {
    installSelectorFakes(
      buildSupportedObjectConfigs(),
      new Map<String, List<CKR_ChecklistGateRule__c>>{
        'Account' => new List<CKR_ChecklistGateRule__c>{
          buildGateRule(
            CKR_TestRecords.fakeId(CKR_ChecklistGateRule__c.SObjectType, 1),
            CKR_TestRecords.fakeId(
              CKR_ChecklistTemplateVersion__c.SObjectType,
              1
            ),
            new Map<String, Object>{
              'CKR_ProtectedActionType__c' => 'SpecificFieldValueChange',
              'CKR_TargetFieldApiName__c' => 'Rating',
              'CKR_TargetValue__c' => 'Hot',
              'CKR_ErrorMessage__c' => 'Complete checklist'
            }
          )
        }
      },
      new Map<Id, Set<Id>>()
    );
    CKR_AppFactory.setMock(
      CKR_IGateBypass.class,
      CKR_Mocks.stub(
        CKR_IGateBypass.class,
        new CKR_Mocks.MethodRecorder().when('source', source)
      )
    );
    CKR_Mocks.MethodRecorder dml =
      new CKR_Mocks.MethodRecorder().when(
        'doInsert',
        new List<Database.SaveResult>()
      );
    CKR_AppFactory.setMock(
      CKR_ISystemDmlGateway.class,
      CKR_Mocks.stub(CKR_ISystemDmlGateway.class, dml)
    );
    return dml;
  }

  private static List<CKR_ChecklistGateRequest> bypassRequests(
    Integer count,
    Integer blocked
  ) {
    List<CKR_ChecklistGateRequest> requests =
      new List<CKR_ChecklistGateRequest>();
    for (Integer i = 0; i < count; i++) {
      CKR_ChecklistGateRequest request = new CKR_ChecklistGateRequest();
      request.recordId = CKR_TestRecords.fakeId(Account.SObjectType, i + 1);
      request.objectApiName = 'Account';
      request.oldRecord = new Account(Rating = 'Cold');
      request.newRecord = new Account(Rating = i < blocked ? 'Hot' : 'Warm');
      requests.add(request);
    }
    return requests;
  }

  private static Integer verifyBypassAndCountEvents(
    String source,
    Integer count,
    Integer blocked
  ) {
    CKR_Mocks.MethodRecorder dml = setupBypass(source);
    try {
      List<CKR_ChecklistGateResult> results =
        new CKR_DefaultChecklistGateService().evaluate(
          bypassRequests(count, blocked)
        );
      System.Assert.areEqual(
          blocked,
          results.size(),
          'Only matching blocked saves return results.'
        );
      for (CKR_ChecklistGateResult result : results) {
        System.Assert.isTrue(result.allowed);
      }
      System.Assert.areEqual(
          blocked == 0 ? 0 : 1,
          dml.callCount('doInsert'),
          'Audit writes must be bulked.'
        );
      if (blocked == 0) {
        return 0;
      }
      System.Assert.areEqual(
          CKR_DmlMode.ALL_OR_NONE,
          dml.lastArguments('doInsert')[1],
          'Audit failure must abort the save.'
        );
      List<SObject> events = (List<SObject>) dml.lastArguments('doInsert')[0];
      for (Integer i = 0; i < blocked; i++) {
        CKR_GateBypassEvent__c event = (CKR_GateBypassEvent__c) events[i];
        System.Assert.areEqual(source, event.CKR_Source__c);
        System.Assert.areEqual(UserInfo.getUserId(), event.CKR_Actor__c);
        System.Assert.areEqual(
            String.valueOf(results[i].recordId),
            event.CKR_RecordId__c
          );
        System.Assert.areEqual('Account', event.CKR_ObjectApiName__c);
        System.Assert.areEqual(results[i].gateRuleId, event.CKR_GateRule__c);
        System.Assert.isNotNull(event.CKR_OccurredOn__c);
        System.Assert.areEqual('Complete checklist', event.CKR_Details__c);
      }
      return events.size();
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  private static List<CKR_ChecklistInstance__c> completeInstances(
    Map<Id, Set<Id>> versionsByRecord
  ) {
    List<CKR_ChecklistInstance__c> instances =
      new List<CKR_ChecklistInstance__c>();
    for (Id recordId : versionsByRecord.keySet()) {
      for (Id versionId : versionsByRecord.get(recordId)) {
        instances.add(
          new CKR_ChecklistInstance__c(
            CKR_ParentRecordId__c = recordId,
            CKR_ChecklistTemplate__c =
              CKR_TestRecords.fakeId(CKR_ChecklistTemplate__c.SObjectType, 1),
            CKR_ChecklistTemplateVersion__c = versionId,
            CKR_IsComplete__c = true
          )
        );
      }
    }
    return instances;
  }

  @IsTest
  static void cutoverUsesInstanceVersion() {
    Id parentId = CKR_TestRecords.fakeId(Account.SObjectType, 10);
    Id v1 =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 10);
    Id v2 =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 11);
    CKR_ChecklistGateRule__c oldRule =
      buildGateRule(
        CKR_TestRecords.fakeId(CKR_ChecklistGateRule__c.SObjectType, 10),
        v1,
        new Map<String, Object>{
          'CKR_ProtectedActionType__c' => 'AnyFieldValueChange',
          'CKR_TargetFieldApiName__c' => 'Industry',
          'CKR_ErrorMessage__c' => 'v1'
        }
      );
    oldRule.CKR_ChecklistTemplateVersion__r.CKR_Status__c = 'Historical';
    CKR_ChecklistGateRule__c newRule =
      buildGateRule(
        CKR_TestRecords.fakeId(CKR_ChecklistGateRule__c.SObjectType, 11),
        v2,
        new Map<String, Object>{
          'CKR_ProtectedActionType__c' => 'AnyFieldValueChange',
          'CKR_TargetFieldApiName__c' => 'Rating',
          'CKR_ErrorMessage__c' => 'v2'
        }
      );
    installSelectorFakes(
      buildSupportedObjectConfigs(),
      new Map<String, List<CKR_ChecklistGateRule__c>>{
        'Account' => new List<CKR_ChecklistGateRule__c>{ newRule, oldRule }
      },
      new Map<Id, Set<Id>>()
    );
    CKR_Mocks.MethodRecorder gate =
      new CKR_Mocks.MethodRecorder().when(
        'selectActivePublishedGateRulesByObjectApiName',
        new Map<String, List<CKR_ChecklistGateRule__c>>{
          'Account' => new List<CKR_ChecklistGateRule__c>{ newRule, oldRule }
        }
      );
    CKR_AppFactory.setMock(
      CKR_IChecklistGateSelector.class,
      CKR_Mocks.stub(CKR_IChecklistGateSelector.class, gate)
    );
    CKR_ChecklistInstance__c instance =
      new CKR_ChecklistInstance__c(
        CKR_ParentRecordId__c = parentId,
        CKR_ChecklistTemplate__c =
          oldRule.CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__c,
        CKR_ChecklistTemplateVersion__c = v1,
        CKR_IsComplete__c = true
      );
    gate.when(
      'selectInstancesByRecordId',
      new List<CKR_ChecklistInstance__c>{ instance }
    );
    CKR_ChecklistGateRequest request = new CKR_ChecklistGateRequest();
    request.recordId = parentId;
    request.objectApiName = 'Account';
    request.oldRecord = new Account(Industry = 'Banking', Rating = 'Cold');
    request.newRecord = new Account(Industry = 'Technology', Rating = 'Hot');
    CKR_DefaultChecklistGateService service =
      new CKR_DefaultChecklistGateService();
    System.Assert.isTrue(
        service.evaluate(new List<CKR_ChecklistGateRequest>{ request })
          .isEmpty(),
        'Complete v1 passes after cutover.'
      );
    instance.CKR_IsComplete__c = false;
    System.Assert.areEqual(
        'v1',
        service.evaluate(new List<CKR_ChecklistGateRequest>{ request })[0]
          .errorMessage,
        'Incomplete v1 uses v1 rules despite v2 priority.'
      );
    request.newRecord = new Account(Industry = 'Banking', Rating = 'Hot');
    System.Assert.isTrue(
        service.evaluate(new List<CKR_ChecklistGateRequest>{ request })
          .isEmpty(),
        'A v2-only rule cannot block a v1 instance.'
      );
    gate.when(
      'selectInstancesByRecordId',
      new List<CKR_ChecklistInstance__c>()
    );
    System.Assert.areEqual(
        'v2',
        service.evaluate(new List<CKR_ChecklistGateRequest>{ request })[0]
          .errorMessage,
        'Without an instance, Published v2 applies.'
      );
    CKR_AppFactory.clearMocks();
  }

  private static void installSelectorFakes(
    Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig> supportedConfigs,
    Map<String, List<CKR_ChecklistGateRule__c>> gateRulesByObjectApiName,
    Map<Id, Set<Id>> completeTemplateVersionsByRecordId
  ) {
    CKR_AppFactory.setMock(
      CKR_ISupportedObjectSelector.class,
      CKR_Mocks.stub(
        CKR_ISupportedObjectSelector.class,
        new CKR_Mocks.MethodRecorder().when(
          'selectActiveByObjectApiName',
          supportedConfigs
        )
      )
    );
    CKR_AppFactory.setMock(
      CKR_IChecklistGateSelector.class,
      CKR_Mocks.stub(
        CKR_IChecklistGateSelector.class,
        new CKR_Mocks.MethodRecorder()
          .when(
            'selectActivePublishedGateRulesByObjectApiName',
            gateRulesByObjectApiName
          )
          .when(
            'selectInstancesByRecordId',
            completeInstances(completeTemplateVersionsByRecordId)
          )
      )
    );
  }

  private static Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig> buildSupportedObjectConfigs() {
    CKR_SupportedObjectSelector.SupportedObjectConfig accountConfig =
      new CKR_SupportedObjectSelector.SupportedObjectConfig();
    accountConfig.objectApiName = 'Account';
    accountConfig.objectLabel = 'Account';
    accountConfig.supportsGates = true;

    return new Map<String, CKR_SupportedObjectSelector.SupportedObjectConfig>{
      'Account' => accountConfig
    };
  }

  private static CKR_ChecklistGateRule__c buildGateRule(
    Id gateRuleId,
    Id versionId,
    Map<String, Object> ruleFields
  ) {
    Map<String, Object> recordFields =
      new Map<String, Object>{
        'Id' => gateRuleId,
        'Name' => 'Gate Rule',
        'CKR_ChecklistTemplateVersion__c' => versionId,
        'CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__c' => CKR_TestRecords.fakeId(
          CKR_ChecklistTemplate__c.SObjectType,
          1
        ),
        'CKR_ChecklistTemplateVersion__r.CKR_Status__c' => 'Published',
        'CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__r.CKR_TargetObjectApiName__c' => 'Account'
      };
    recordFields.putAll(ruleFields);
    return (CKR_ChecklistGateRule__c) CKR_TestRecords.build(
      CKR_ChecklistGateRule__c.SObjectType,
      recordFields
    );
  }
}
