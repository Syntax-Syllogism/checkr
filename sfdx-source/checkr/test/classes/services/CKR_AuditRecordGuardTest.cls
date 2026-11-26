@IsTest
private class CKR_AuditRecordGuardTest {
  @IsTest
  static void blocksEveryRowWithoutPermission() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      List<SObject> rows =
        new List<SObject>{
          new CKR_ChecklistAuditEvent__c(),
          new CKR_GateBypassEvent__c()
        };
      CKR_AuditRecordGuard.blockUnlessMaintainer(rows);
      for (SObject row : rows) {
        System.Assert.isTrue(row.hasErrors());
        System.Assert.areEqual(
            CKR_AuditRecordGuard.MESSAGE,
            row.getErrors()[0].getMessage()
          );
      }
    }
  }

  @IsTest
  static void bulkDeleteProtectsOnlyAuditedInstances() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      List<CKR_ChecklistInstance__c> rows =
        new List<CKR_ChecklistInstance__c>();
      Set<Id> protectedIds = new Set<Id>();
      for (Integer i = 1; i <= 200; i++) {
        Id key =
          CKR_TestRecords.fakeId(CKR_ChecklistInstance__c.SObjectType, i);
        rows.add(new CKR_ChecklistInstance__c(Id = key));
        if (Math.mod(i, 2) == 0) {
          protectedIds.add(key);
        }
      }
      CKR_Mocks.MethodRecorder recorder =
        new CKR_Mocks.MethodRecorder().when(
          'selectAuditedInstanceIds',
          protectedIds
        );
      CKR_AppFactory.setMock(
        CKR_IAuditRetentionSelector.class,
        CKR_Mocks.stub(CKR_IAuditRetentionSelector.class, recorder)
      );
      CKR_AuditRecordGuard.validateInstanceDeletes(rows);
      System.Assert.areEqual(1, recorder.callCount('selectAuditedInstanceIds'));
      System.Assert.areEqual(
          200,
          (
            (Set<Id>) recorder.lastArguments('selectAuditedInstanceIds')[0]
          ).size()
        );
      for (CKR_ChecklistInstance__c row : rows) {
        System.Assert.areEqual(protectedIds.contains(row.Id), row.hasErrors());
      }
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void bulkDeleteProtectsOnlyAuditedItems() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      List<CKR_ChecklistInstanceItem__c> rows =
        new List<CKR_ChecklistInstanceItem__c>();
      Set<Id> protectedIds = new Set<Id>();
      for (Integer i = 1; i <= 200; i++) {
        Id key =
          CKR_TestRecords.fakeId(CKR_ChecklistInstanceItem__c.SObjectType, i);
        rows.add(new CKR_ChecklistInstanceItem__c(Id = key));
        if (Math.mod(i, 2) == 0) {
          protectedIds.add(key);
        }
      }
      CKR_Mocks.MethodRecorder recorder =
        new CKR_Mocks.MethodRecorder().when(
          'selectAuditedItemIds',
          protectedIds
        );
      CKR_AppFactory.setMock(
        CKR_IAuditRetentionSelector.class,
        CKR_Mocks.stub(CKR_IAuditRetentionSelector.class, recorder)
      );
      CKR_AuditRecordGuard.validateItemDeletes(rows);
      System.Assert.areEqual(1, recorder.callCount('selectAuditedItemIds'));
      System.Assert.areEqual(
          new Map<Id, CKR_ChecklistInstanceItem__c>(rows).keySet(),
          (Set<Id>) recorder.lastArguments('selectAuditedItemIds')[0]
        );
      for (CKR_ChecklistInstanceItem__c row : rows) {
        System.Assert.areEqual(protectedIds.contains(row.Id), row.hasErrors());
        if (row.hasErrors()) {
          assertBlocked(row.getErrors());
        }
      }
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void triggersAndSystemInsert_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_ChecklistTemplate__c template =
        new CKR_ChecklistTemplate__c(
          Name = 'Audit test',
          CKR_DeveloperName__c = 'AuditTest',
          CKR_TargetObjectApiName__c = 'Account',
          CKR_SupportedObjectDeveloperName__c = 'Account'
        );
      insert template;
      CKR_ChecklistTemplateVersion__c version =
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = template.Id,
          CKR_Status__c = 'Draft',
          CKR_VersionNumber__c = 1,
          CKR_CompletionAccessMode__c = 'EditAccess'
        );
      insert version;
      List<CKR_ChecklistInstance__c> instances =
        new List<CKR_ChecklistInstance__c>();
      for (Integer i = 0; i < 2; i++) {
        instances.add(
          new CKR_ChecklistInstance__c(
            CKR_ChecklistTemplate__c = template.Id,
            CKR_ChecklistTemplateVersion__c = version.Id,
            CKR_ParentRecordId__c =
              String.valueOf(CKR_TestRecords.fakeId(Account.SObjectType, 1)),
            CKR_ParentObjectApiName__c = 'Account',
            CKR_UniqueKey__c = 'audit' + i
          )
        );
      }
      insert instances;
      List<CKR_ChecklistInstanceItem__c> items =
        new List<CKR_ChecklistInstanceItem__c>();
      for (Integer i = 0; i < 2; i++) {
        items.add(
          new CKR_ChecklistInstanceItem__c(
            CKR_ChecklistInstance__c = instances[0].Id,
            CKR_SourceType__c = 'AdHoc',
            CKR_Label__c = 'Audit item ' + i,
            CKR_ExplanationInputType__c = 'Text'
          )
        );
      }
      insert items;
      CKR_ChecklistAuditEvent__c event =
        new CKR_ChecklistAuditEvent__c(
          CKR_ChecklistInstance__c = instances[0].Id,
          CKR_ChecklistInstanceItem__c = items[0].Id,
          CKR_EventType__c = 'ItemCompleted'
        );
      (
        (CKR_IChecklistAuditService) CKR_AppFactory.getInstance(
          CKR_IChecklistAuditService.class
        )
      ).record(new List<CKR_ChecklistAuditEvent__c>{ event });
      System.Assert.isNotNull(
          event.Id,
          'System-authored insert is still allowed.'
        );
      // Send only the changed field; the master-detail parent is not updatable.
      assertBlocked(
        Database.update(
            new CKR_ChecklistAuditEvent__c(
              Id = event.Id,
              CKR_Details__c = 'rewrite'
            ),
            false
          )
          .getErrors()
      );
      assertBlocked(Database.delete(event, false).getErrors());
      CKR_GateBypassEvent__c bypass =
        new CKR_GateBypassEvent__c(
          CKR_RecordId__c =
            String.valueOf(CKR_TestRecords.fakeId(Account.SObjectType, 1)),
          CKR_ObjectApiName__c = 'Account',
          CKR_Source__c = 'CustomPermission',
          CKR_Actor__c = UserInfo.getUserId(),
          CKR_OccurredOn__c = System.now()
        );
      insert bypass;
      // Send only the changed field, as production updates do.
      assertBlocked(
        Database.update(
            new CKR_GateBypassEvent__c(
              Id = bypass.Id,
              CKR_Details__c = 'rewrite'
            ),
            false
          )
          .getErrors()
      );
      assertBlocked(Database.delete(bypass, false).getErrors());
      Integer queries = Limits.getQueries();
      CKR_IAuditRetentionSelector selector =
        (CKR_IAuditRetentionSelector) CKR_AppFactory.getInstance(
          CKR_IAuditRetentionSelector.class
        );
      System.Assert.areEqual(
          new Set<Id>{ instances[0].Id },
          selector.selectAuditedInstanceIds(
            new Map<Id, CKR_ChecklistInstance__c>(instances).keySet()
          )
        );
      System.Assert.areEqual(
          1,
          Limits.getQueries() - queries,
          'One bulk aggregate query.'
        );
      queries = Limits.getQueries();
      System.Assert.areEqual(
          new Set<Id>{ items[0].Id },
          selector.selectAuditedItemIds(
            new Map<Id, CKR_ChecklistInstanceItem__c>(items).keySet()
          )
        );
      System.Assert.areEqual(
          1,
          Limits.getQueries() - queries,
          'One bulk item aggregate query.'
        );
      List<Database.DeleteResult> itemResults = Database.delete(items, false);
      assertBlocked(itemResults[0].getErrors());
      System.Assert.isTrue(
          itemResults[1].isSuccess(),
          'Unaudited item remains deletable.'
        );
      System.Assert.areEqual(
          items[0].Id,
          [
            SELECT CKR_ChecklistInstanceItem__c
            FROM CKR_ChecklistAuditEvent__c
            WHERE Id = :event.Id
          ]
            .CKR_ChecklistInstanceItem__c,
          'Blocked item deletion preserves the audit link.'
        );
      List<Database.DeleteResult> results = Database.delete(instances, false);
      assertBlocked(results[0].getErrors());
      System.Assert.isTrue(
          results[1].isSuccess(),
          'Unaudited instance remains deletable.'
        );
      System.Assert.areEqual(
          1,
          [SELECT COUNT() FROM CKR_ChecklistAuditEvent__c WHERE Id = :event.Id]
        );
    }
  }

  @IsTest
  static void bulkDeleteProtectsOnlyBypassReferencedParents() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      for (Boolean templates : new List<Boolean>{ true, false }) {
        List<SObject> rows = new List<SObject>();
        Set<Id> protectedIds = new Set<Id>();
        for (Integer i = 1; i <= 200; i++) {
          SObject row =
            templates
            ? (SObject) new CKR_ChecklistTemplate__c()
            : (SObject) new CKR_ChecklistTemplateVersion__c();
          row.Id = CKR_TestRecords.fakeId(row.getSObjectType(), i);
          rows.add(row);
          if (Math.mod(i, 2) == 0) {
            protectedIds.add(row.Id);
          }
        }
        String selectorMethod =
          templates
          ? 'selectBypassReferencedTemplateIds'
          : 'selectBypassReferencedVersionIds';
        CKR_Mocks.MethodRecorder recorder =
          new CKR_Mocks.MethodRecorder().when(selectorMethod, protectedIds);
        CKR_AppFactory.setMock(
          CKR_IAuditRetentionSelector.class,
          CKR_Mocks.stub(CKR_IAuditRetentionSelector.class, recorder)
        );
        CKR_AuditRecordGuard.validateGateRuleParentDeletes(rows);
        System.Assert.areEqual(1, recorder.callCount(selectorMethod));
        System.Assert.areEqual(
            200,
            ((Set<Id>) recorder.lastArguments(selectorMethod)[0]).size()
          );
        assertParentDeleteErrors(rows, protectedIds);
        CKR_AppFactory.clearMocks();
      }
    }
  }

  private static void assertParentDeleteErrors(
    List<SObject> rows,
    Set<Id> protectedIds
  ) {
    for (SObject row : rows) {
      System.Assert.areEqual(protectedIds.contains(row.Id), row.hasErrors());
      if (row.hasErrors()) {
        System.Assert.areEqual(
            CKR_AuditRecordGuard.REFERENCED_RULE_MESSAGE,
            row.getErrors()[0].getMessage()
          );
      }
    }
  }

  @IsTest
  static void referencedGateRuleDeletion_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.TemplateFixture fixture =
        CKR_TestDataFactory.createDraftAccountTemplate('Bypass retention');
      List<CKR_ChecklistGateRule__c> rules =
        new List<CKR_ChecklistGateRule__c>();
      for (Integer i = 0; i < 2; i++) {
        rules.add(
          new CKR_ChecklistGateRule__c(
            CKR_ChecklistTemplateVersion__c = fixture.versionId,
            CKR_ProtectedActionType__c = 'AnyFieldValueChange',
            CKR_TargetFieldApiName__c = 'Rating'
          )
        );
      }
      insert rules;
      CKR_GateBypassEvent__c bypass =
        new CKR_GateBypassEvent__c(
          CKR_GateRule__c = rules[0].Id,
          CKR_RecordId__c =
            String.valueOf(CKR_TestRecords.fakeId(Account.SObjectType, 1)),
          CKR_Source__c = 'CustomPermission'
        );
      insert bypass;
      CKR_IAuditRetentionSelector selector = new CKR_AuditRetentionSelector();
      System.Assert.areEqual(
          new Set<Id>{ fixture.templateId },
          selector.selectBypassReferencedTemplateIds(
            new Set<Id>{ fixture.templateId }
          ),
          'Grouped relationship results expose the template Id by its leaf field name.'
        );
      System.Assert.areEqual(
          new Set<Id>{ fixture.versionId },
          selector.selectBypassReferencedVersionIds(
            new Set<Id>{ fixture.versionId }
          ),
          'Version retention returns the referenced version Id.'
        );
      List<Database.DeleteResult> results = Database.delete(rules, false);
      System.Assert.isFalse(
          results[0].isSuccess(),
          'Referenced Draft rule must remain.'
        );
      System.Assert.areEqual(
          StatusCode.DELETE_FAILED,
          results[0].getErrors()[0].getStatusCode()
        );
      System.Assert.isTrue(
          results[1].isSuccess(),
          'Unreferenced Draft rule remains deletable.'
        );
      List<SObject> parents =
        new List<SObject>{
          new CKR_ChecklistTemplateVersion__c(Id = fixture.versionId),
          new CKR_ChecklistTemplate__c(Id = fixture.templateId)
        };
      for (Database.DeleteResult deletion : Database.delete(parents, false)) {
        System.Assert.isFalse(
            deletion.isSuccess(),
            'Parent cascade must preserve referenced rules.'
          );
        System.Assert.areEqual(1, deletion.getErrors().size());
        System.Assert.areEqual(
            StatusCode.FIELD_CUSTOM_VALIDATION_EXCEPTION,
            deletion.getErrors()[0].getStatusCode(),
            'Deletion must fail through addError, not an unhandled query exception.'
          );
        System.Assert.areEqual(
            CKR_AuditRecordGuard.REFERENCED_RULE_MESSAGE,
            deletion.getErrors()[0].getMessage(),
            'The retention guard supplies the intended per-record error.'
          );
      }
      System.Assert.areEqual(
          rules[0].Id,
          [
            SELECT CKR_GateRule__c
            FROM CKR_GateBypassEvent__c
            WHERE Id = :bypass.Id
          ]
            .CKR_GateRule__c,
          'Every blocked deletion preserves the bypass event and its rule link.'
        );
      System.Assert.areEqual(
          1,
          [SELECT COUNT() FROM CKR_ChecklistGateRule__c WHERE Id = :rules[0].Id]
        );
    }
  }

  private static void assertBlocked(List<Database.Error> errors) {
    System.Assert.areEqual(1, errors.size());
    System.Assert.areEqual(
        CKR_AuditRecordGuard.MESSAGE,
        errors[0].getMessage()
      );
  }
}
