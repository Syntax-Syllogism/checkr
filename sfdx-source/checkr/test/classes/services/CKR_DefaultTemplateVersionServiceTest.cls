@IsTest
private class CKR_DefaultTemplateVersionServiceTest {
  @IsTest
  static void publishesAndCutsOver_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.TemplateFixture fixture =
        CKR_TestDataFactory.createPublishedAccountTemplate('Publish test');
      CKR_ChecklistTemplateVersion__c second =
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = fixture.templateId,
          CKR_VersionNumber__c = 2,
          CKR_Status__c = 'Draft'
        );
      insert second;
      CKR_TestDataFactory.addAccountTemplateItems(second.Id);
      new CKR_DefaultTemplateVersionService().publish(second.Id);
      Map<Id, CKR_ChecklistTemplateVersion__c> versions =
        new Map<Id, CKR_ChecklistTemplateVersion__c>(
          [
            SELECT CKR_Status__c, CKR_PublishedBy__c, CKR_PublishedOn__c
            FROM CKR_ChecklistTemplateVersion__c
            WHERE CKR_ChecklistTemplate__c = :fixture.templateId
          ]
        );
      System.Assert.areEqual(
          'Historical',
          versions.get(fixture.versionId).CKR_Status__c,
          'Previous version becomes Historical.'
        );
      System.Assert.areEqual(
          'Published',
          versions.get(second.Id).CKR_Status__c,
          'Draft is published.'
        );
      System.Assert.areEqual(
          UserInfo.getUserId(),
          versions.get(second.Id).CKR_PublishedBy__c,
          'Publisher is recorded.'
        );
      System.Assert.isNotNull(
          versions.get(second.Id).CKR_PublishedOn__c,
          'Publish time is recorded.'
        );
      System.Assert.areEqual(
          second.Id,
          [
            SELECT CKR_CurrentPublishedVersion__c
            FROM CKR_ChecklistTemplate__c
            WHERE Id = :fixture.templateId
          ]
            .CKR_CurrentPublishedVersion__c,
          'Pointer follows cutover.'
        );
      System.Assert.areEqual(
          1,
          [
            SELECT COUNT()
            FROM CKR_ChecklistTemplateVersion__c
            WHERE
              CKR_ChecklistTemplate__c = :fixture.templateId
              AND CKR_Status__c = 'Published'
          ],
          'Exactly one version is Published.'
        );
      CKR_ChecklistTemplateItem__c historicalItem = [
        SELECT Id
        FROM CKR_ChecklistTemplateItem__c
        WHERE CKR_ChecklistTemplateVersion__c = :fixture.versionId
        LIMIT 1
      ];
      historicalItem.CKR_Label__c = 'Forbidden historical edit';
      System.Assert.isFalse(
          Database.update(historicalItem, false).isSuccess(),
          'Historical items stay immutable after cutover.'
        );
      assertRejected(second.Id, 'Only Draft');
      assertRejected(fixture.versionId, 'Only Draft');
    }
  }
  @IsTest
  static void emptyAndMissingVersionRejected_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.TemplateFixture fixture =
        CKR_TestDataFactory.createDraftAccountTemplate('Empty version');
      assertRejected(fixture.versionId, 'at least one item');
      assertRejected(null, 'existing draft');
      System.Assert.areEqual(
          'Draft',
          [
            SELECT CKR_Status__c
            FROM CKR_ChecklistTemplateVersion__c
            WHERE Id = :fixture.versionId
          ]
            .CKR_Status__c,
          'Failed publish leaves Draft unchanged.'
        );
    }
  }
  @IsTest
  static void directStatusAndPublishedEditsRejected_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.TemplateFixture fixture =
        CKR_TestDataFactory.createDraftAccountTemplate('Guard test');
      CKR_TestDataFactory.addAccountTemplateItems(fixture.versionId);
      CKR_ChecklistGateRule__c rule =
        new CKR_ChecklistGateRule__c(
          CKR_ChecklistTemplateVersion__c = fixture.versionId,
          CKR_TargetFieldApiName__c = 'Rating',
          CKR_ProtectedActionType__c = 'AnyFieldValueChange'
        );
      insert rule;
      Database.SaveResult manual =
        Database.update(
          new CKR_ChecklistTemplateVersion__c(
            Id = fixture.versionId,
            CKR_Status__c = 'Published'
          ),
          false
        );
      System.Assert.isFalse(
          manual.isSuccess(),
          'Manual publishing cannot bypass the service.'
        );
      new CKR_DefaultTemplateVersionService().publish(fixture.versionId);
      Database.SaveResult editVersion =
        Database.update(
          new CKR_ChecklistTemplateVersion__c(
            Id = fixture.versionId,
            CKR_Status__c = 'Draft'
          ),
          false
        );
      System.Assert.isFalse(
          editVersion.isSuccess(),
          'Published cannot be reopened.'
        );
      CKR_ChecklistTemplateItem__c item = [
        SELECT Id
        FROM CKR_ChecklistTemplateItem__c
        WHERE CKR_ChecklistTemplateVersion__c = :fixture.versionId
        LIMIT 1
      ];
      item.CKR_Label__c = 'Changed';
      System.Assert.isFalse(
          Database.update(item, false).isSuccess(),
          'Published items are immutable.'
        );
      rule.CKR_ErrorMessage__c = 'Changed';
      System.Assert.isFalse(
          Database.update(rule, false).isSuccess(),
          'Published rules are immutable.'
        );
      System.Assert.isFalse(
          Database.delete(item, false).isSuccess(),
          'Published items cannot be deleted.'
        );
      System.Assert.isFalse(
          Database.delete(rule, false).isSuccess(),
          'Published rules cannot be deleted.'
        );
      System.Assert.isFalse(
          Database.delete(
              new CKR_ChecklistTemplateVersion__c(Id = fixture.versionId),
              false
            )
            .isSuccess(),
          'Published versions cannot be deleted.'
        );
      CKR_TestDataFactory.TemplateFixture draft =
        CKR_TestDataFactory.createDraftAccountTemplate('Direct insert');
      System.Assert.isFalse(
          Database.insert(
              new CKR_ChecklistTemplateVersion__c(
                CKR_ChecklistTemplate__c = draft.templateId,
                CKR_Status__c = 'Published',
                CKR_VersionNumber__c = 2
              ),
              false
            )
            .isSuccess(),
          'Published insert is blocked as well.'
        );
    }
  }
  @IsTest
  static void pointerFailureRollsBack_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.TemplateFixture fixture =
        CKR_TestDataFactory.createPublishedAccountTemplate('Rollback');
      CKR_ChecklistTemplateVersion__c second =
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = fixture.templateId,
          CKR_Status__c = 'Draft',
          CKR_VersionNumber__c = 2
        );
      insert second;
      CKR_TestDataFactory.addAccountTemplateItems(second.Id);
      // Execute the lifecycle writes, then fail the pointer update; the caught error must roll back both.
      CKR_Mocks.MethodRecorder gateway =
        new CKR_Mocks.MethodRecorder()
          .performsRealUpdates()
          .whenThrowOnCall(
            'doUpdate',
            2,
            new CKR_DefaultTemplateVersionService.PublishException(
              'write denied'
            )
          );
      CKR_AppFactory.setMock(
        CKR_IDmlGateway.class,
        CKR_Mocks.stub(CKR_IDmlGateway.class, gateway)
      );
      assertRejected(second.Id, 'write denied');
      CKR_AppFactory.clearMocks();
      System.Assert.areEqual(
          'Published',
          [
            SELECT CKR_Status__c
            FROM CKR_ChecklistTemplateVersion__c
            WHERE Id = :fixture.versionId
          ]
            .CKR_Status__c,
          'Failure retains previous publish.'
        );
      System.Assert.areEqual(
          'Draft',
          [
            SELECT CKR_Status__c
            FROM CKR_ChecklistTemplateVersion__c
            WHERE Id = :second.Id
          ]
            .CKR_Status__c,
          'Failed pointer write rolls the new version back to Draft.'
        );
      System.Assert.areEqual(
          fixture.versionId,
          [
            SELECT CKR_CurrentPublishedVersion__c
            FROM CKR_ChecklistTemplate__c
            WHERE Id = :fixture.templateId
          ]
            .CKR_CurrentPublishedVersion__c,
          'Failed cutover preserves the original pointer.'
        );
      System.Assert.isFalse(
          CKR_DefaultTemplateVersionService.isLifecycleWrite(second.Id),
          'Authorization is cleared after failure.'
        );
    }
  }
  @IsTest
  static void reparentingImmutableChildrenRejected_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.TemplateFixture fixture =
        CKR_TestDataFactory.createDraftAccountTemplate('Reparent guard');
      CKR_TestDataFactory.addAccountTemplateItems(fixture.versionId);
      CKR_ChecklistTemplateItem__c item = [
        SELECT Id
        FROM CKR_ChecklistTemplateItem__c
        WHERE CKR_ChecklistTemplateVersion__c = :fixture.versionId
        LIMIT 1
      ];
      CKR_ChecklistGateRule__c rule =
        new CKR_ChecklistGateRule__c(
          CKR_ChecklistTemplateVersion__c = fixture.versionId,
          CKR_TargetFieldApiName__c = 'Rating',
          CKR_ProtectedActionType__c = 'AnyFieldValueChange'
        );
      insert rule;
      CKR_ChecklistTemplateVersion__c second =
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = fixture.templateId,
          CKR_VersionNumber__c = 2,
          CKR_Status__c = 'Draft'
        );
      CKR_ChecklistTemplateVersion__c destination =
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = fixture.templateId,
          CKR_VersionNumber__c = 3,
          CKR_Status__c = 'Draft'
        );
      insert new List<CKR_ChecklistTemplateVersion__c>{ second, destination };
      CKR_TestDataFactory.addAccountTemplateItems(second.Id);
      new CKR_DefaultTemplateVersionService().publish(fixture.versionId);
      assertReparentingRejected(item.Id, rule, destination.Id);
      new CKR_DefaultTemplateVersionService().publish(second.Id);
      assertReparentingRejected(item.Id, rule, destination.Id);
      System.Assert.areEqual(
          'Historical',
          [
            SELECT CKR_Status__c
            FROM CKR_ChecklistTemplateVersion__c
            WHERE Id = :fixture.versionId
          ]
            .CKR_Status__c,
          'The second rejection exercises the now-historical snapshot.'
        );
    }
  }
  private static void assertReparentingRejected(
    Id itemId,
    CKR_ChecklistGateRule__c rule,
    Id draftVersionId
  ) {
    // Both master-detail fields disable reparenting independently of validation formulas.
    Database.SaveResult itemMove =
      Database.update(
        new CKR_ChecklistTemplateItem__c(
          Id = itemId,
          CKR_ChecklistTemplateVersion__c = draftVersionId
        ),
        false
      );
    Database.SaveResult ruleMove =
      Database.update(
        new CKR_ChecklistGateRule__c(
          Id = rule.Id,
          CKR_ChecklistTemplateVersion__c = draftVersionId
        ),
        false
      );
    System.Assert.isFalse(
        itemMove.isSuccess(),
        'Immutable item cannot move to Draft.'
      );
    System.Assert.isFalse(
        ruleMove.isSuccess(),
        'Immutable rule cannot move to Draft.'
      );
    System.Assert.areEqual(
        rule.CKR_ChecklistTemplateVersion__c,
        [
          SELECT CKR_ChecklistTemplateVersion__c
          FROM CKR_ChecklistTemplateItem__c
          WHERE Id = :itemId
        ]
          .CKR_ChecklistTemplateVersion__c,
        'Immutable item remains in its snapshot.'
      );
    System.Assert.areEqual(
        rule.CKR_ChecklistTemplateVersion__c,
        [
          SELECT CKR_ChecklistTemplateVersion__c
          FROM CKR_ChecklistGateRule__c
          WHERE Id = :rule.Id
        ]
          .CKR_ChecklistTemplateVersion__c,
        'Immutable rule remains in its snapshot.'
      );
  }
  @IsTest
  static void publishesThroughMockedPorts() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Id versionId =
        CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 1);
      Id previousId =
        CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 2);
      Id templateId =
        CKR_TestRecords.fakeId(CKR_ChecklistTemplate__c.SObjectType, 1);
      CKR_Mocks.MethodRecorder selector =
        new CKR_Mocks.MethodRecorder()
          .when(
            'selectVersion',
            new CKR_ChecklistTemplateVersion__c(
              Id = versionId,
              CKR_ChecklistTemplate__c = templateId,
              CKR_Status__c = 'Draft'
            )
          )
          .when('lockTemplate', new CKR_ChecklistTemplate__c(Id = templateId))
          .when('countItems', 1)
          .when(
            'selectPublishedVersions',
            new List<CKR_ChecklistTemplateVersion__c>{
              new CKR_ChecklistTemplateVersion__c(Id = previousId)
            }
          );
      CKR_Mocks.MethodRecorder gateway = new CKR_Mocks.MethodRecorder();
      CKR_AppFactory.setMock(
        CKR_IChecklistTemplateVersionSelector.class,
        CKR_Mocks.stub(CKR_IChecklistTemplateVersionSelector.class, selector)
      );
      CKR_AppFactory.setMock(
        CKR_IDmlGateway.class,
        CKR_Mocks.stub(CKR_IDmlGateway.class, gateway)
      );
      new CKR_DefaultTemplateVersionService().publish(versionId);
      System.Assert.areEqual(
          2,
          selector.callCount('selectVersion'),
          'Version is reread after locking.'
        );
      List<SObject> versions =
        (List<SObject>) gateway.argumentsAt('doUpdate', 0)[0];
      System.Assert.areEqual(
          'Historical',
          versions[0].get('CKR_Status__c'),
          'Previous publish is retired.'
        );
      System.Assert.areEqual(
          'Published',
          versions[1].get('CKR_Status__c'),
          'New version is published.'
        );
      List<SObject> pointer =
        (List<SObject>) gateway.argumentsAt('doUpdate', 1)[0];
      System.Assert.areEqual(
          versionId,
          pointer[0].get('CKR_CurrentPublishedVersion__c'),
          'Pointer is updated.'
        );
      CKR_AppFactory.clearMocks();
    }
  }
  private static void assertRejected(Id versionId, String messagePart) {
    try {
      new CKR_DefaultTemplateVersionService().publish(versionId);
      System.Assert.fail('Expected rejection.');
    } catch (CKR_DefaultTemplateVersionService.PublishException failure) {
      System.Assert.isTrue(
          failure.getMessage().contains(messagePart),
          'Rejection explains why: ' + failure.getMessage()
        );
    }
  }
}
