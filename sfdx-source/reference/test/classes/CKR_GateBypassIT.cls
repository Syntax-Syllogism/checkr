@IsTest
private class CKR_GateBypassIT {
  private static User userWith(String permissionSetName, String suffix) {
    Profile standard = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    User testUser =
      new User(
        Alias = suffix,
        Email = suffix + '@example.com',
        EmailEncodingKey = 'UTF-8',
        LastName = suffix,
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = standard.Id,
        TimeZoneSidKey = 'America/New_York',
        Username = suffix + '@ckr-permissions.example.com'
      );
    // Running as the current user in its own context avoids MIXED_DML_OPERATION
    // between the user/assignment setup rows and the checklist data.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert testUser;
      insert new PermissionSetAssignment(
        AssigneeId = testUser.Id,
        PermissionSetId =
          [SELECT Id FROM PermissionSet WHERE Name = 'CKR_Admin'].Id
      );
      insert new PermissionSetAssignment(
        AssigneeId = testUser.Id,
        PermissionSetId =
          [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName].Id
      );
    }
    return testUser;
  }

  @IsTest
  static void assignedPermissionUpdatesGatedAccount_integrationHappyPath() {
    User runner = userWith('CKR_GateBypass', 'ckrbyp');
    CKR_TestDataFactory.TemplateFixture fixture =
      CKR_TestDataFactory.createDraftAccountTemplate('Bypass IT');
    CKR_TestDataFactory.addAccountTemplateItems(fixture.versionId);
    CKR_ChecklistGateRule__c rule =
      new CKR_ChecklistGateRule__c(
        CKR_ChecklistTemplateVersion__c = fixture.versionId,
        CKR_Active__c = true,
        CKR_ProtectedActionType__c = 'SpecificFieldValueChange',
        CKR_TargetFieldApiName__c = 'Rating',
        CKR_TargetValue__c = 'Hot'
      );
    insert rule;
    CKR_TestDataFactory.publishTemplateVersion(
      fixture.templateId,
      fixture.versionId
    );
    insert new CKR_Settings__c(
      SetupOwnerId = runner.Id,
      CKR_BypassGate__c = true
    );
    Account account =
      new Account(Name = 'Bypass IT', Rating = 'Cold', OwnerId = runner.Id);
    insert account;
    System.runAs(runner) {
      System.Assert.isTrue(FeatureManagement.checkPermission('CKR_BypassGate'));
      account.Rating = 'Hot';
      update account;
    }
    System.Assert.areEqual(
        'Hot',
        [SELECT Rating FROM Account WHERE Id = :account.Id].Rating
      );
    CKR_GateBypassEvent__c event = [
      SELECT
        CKR_Source__c,
        CKR_Actor__c,
        CKR_GateRule__c,
        CKR_RecordId__c,
        CKR_ObjectApiName__c,
        CKR_OccurredOn__c
      FROM CKR_GateBypassEvent__c
      WHERE CKR_RecordId__c = :account.Id
    ];
    System.Assert.areEqual(
        'CustomPermission',
        event.CKR_Source__c,
        'Permission wins when both switches are active.'
      );
    System.Assert.areEqual(runner.Id, event.CKR_Actor__c);
    System.Assert.areEqual(rule.Id, event.CKR_GateRule__c);
    System.Assert.areEqual('Account', event.CKR_ObjectApiName__c);
    System.Assert.isNotNull(event.CKR_OccurredOn__c);
  }
}
