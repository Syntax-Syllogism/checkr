@IsTest
private class CKR_ChecklistGateSelectorTest {
  @IsTest
  static void historicalAndPublishedRules_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.TemplateFixture fixture =
        CKR_TestDataFactory.createDraftAccountTemplate('Gate history');
      CKR_TestDataFactory.addAccountTemplateItems(fixture.versionId);
      insert new List<CKR_ChecklistGateRule__c>{
        rule(fixture.versionId),
        inactiveRule(fixture.versionId)
      };
      CKR_TestDataFactory.publishTemplateVersion(
        fixture.templateId,
        fixture.versionId
      );
      CKR_ChecklistTemplateVersion__c second =
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = fixture.templateId,
          CKR_Status__c = 'Draft',
          CKR_VersionNumber__c = 2
        );
      insert second;
      CKR_TestDataFactory.addAccountTemplateItems(second.Id);
      insert rule(second.Id);
      CKR_TestDataFactory.publishTemplateVersion(fixture.templateId, second.Id);
      List<CKR_ChecklistGateRule__c> rules =
        new CKR_ChecklistGateSelector()
          .selectActivePublishedGateRulesByObjectApiName(
            new Set<String>{ 'Account' }
          )
          .get('Account');
      System.Assert.areEqual(
          2,
          rules.size(),
          'Both version statuses are loaded, inactive rules are excluded.'
        );
      Set<Id> versions = new Set<Id>();
      for (CKR_ChecklistGateRule__c row : rules) {
        versions.add(row.CKR_ChecklistTemplateVersion__c);
      }
      System.Assert.isTrue(
          versions.contains(fixture.versionId),
          'Historical rules remain available.'
        );
      System.Assert.isTrue(
          versions.contains(second.Id),
          'Published rules remain available.'
        );
    }
  }
  @IsTest
  static void allInstances_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Account parent = new Account(Name = 'Gate parent');
      insert parent;
      CKR_TestDataFactory.TemplateFixture fixture =
        CKR_TestDataFactory.createPublishedAccountTemplate('Gate instances');
      insert new CKR_ChecklistInstance__c(
        CKR_ChecklistTemplate__c = fixture.templateId,
        CKR_ChecklistTemplateVersion__c = fixture.versionId,
        CKR_ParentRecordId__c = parent.Id,
        CKR_ParentObjectApiName__c = 'Account',
        CKR_IsComplete__c = false
      );
      List<CKR_ChecklistInstance__c> instances =
        new CKR_ChecklistGateSelector().selectInstancesByRecordId(
          new Set<Id>{ parent.Id },
          new Set<Id>{ fixture.templateId }
        );
      System.Assert.areEqual(
          1,
          instances.size(),
          'Incomplete instances also select their version.'
        );
      System.Assert.isFalse(
          instances[0].CKR_IsComplete__c,
          'Completeness is returned without filtering.'
        );
      System.Assert.areEqual(
          fixture.templateId,
          instances[0].CKR_ChecklistTemplate__c,
          'Instances are keyed by template.'
        );
    }
  }
  @IsTest
  static void blankInputs() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_ChecklistGateSelector selector = new CKR_ChecklistGateSelector();
      System.Assert.isTrue(
          selector.selectInstancesByRecordId(null, null).isEmpty(),
          'Null inputs are safe.'
        );
      System.Assert.isTrue(
          selector.selectInstancesByRecordId(new Set<Id>(), new Set<Id>())
            .isEmpty(),
          'Empty inputs are safe.'
        );
      System.Assert.isTrue(
          selector.selectActivePublishedGateRulesByObjectApiName(null)
            .isEmpty(),
          'Null object names are safe.'
        );
    }
  }
  private static CKR_ChecklistGateRule__c inactiveRule(Id versionId) {
    CKR_ChecklistGateRule__c inactive = rule(versionId);
    inactive.CKR_Active__c = false;
    return inactive;
  }

  private static CKR_ChecklistGateRule__c rule(Id versionId) {
    return new CKR_ChecklistGateRule__c(
      Name = 'Rule',
      CKR_ChecklistTemplateVersion__c = versionId,
      CKR_Active__c = true,
      CKR_ProtectedActionType__c = 'AnyFieldValueChange',
      CKR_TargetFieldApiName__c = 'Rating'
    );
  }
}
