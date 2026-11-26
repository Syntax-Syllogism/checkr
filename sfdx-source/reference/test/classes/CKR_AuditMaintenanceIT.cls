@IsTest
private class CKR_AuditMaintenanceIT {
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
  static void assignedMaintenanceAllowsChanges_integrationHappyPath() {
    User runner = userWith('CKR_AuditMaintenance', 'ckrmaint');
    CKR_TestDataFactory.TemplateFixture fixture =
      CKR_TestDataFactory.createDraftAccountTemplate('Audit Maintenance IT');
    CKR_ChecklistInstance__c instance =
      new CKR_ChecklistInstance__c(
        CKR_ChecklistTemplate__c = fixture.templateId,
        CKR_ChecklistTemplateVersion__c = fixture.versionId,
        CKR_ParentObjectApiName__c = 'Account',
        CKR_ParentRecordId__c = '001000000000001AAA',
        CKR_UniqueKey__c = 'maintenance'
      );
    insert instance;
    CKR_ChecklistInstanceItem__c item =
      new CKR_ChecklistInstanceItem__c(
        CKR_ChecklistInstance__c = instance.Id,
        CKR_SourceType__c = 'AdHoc',
        CKR_Label__c = 'Maintenance item',
        CKR_ExplanationInputType__c = 'Text'
      );
    insert item;
    CKR_ChecklistAuditEvent__c event =
      new CKR_ChecklistAuditEvent__c(
        CKR_ChecklistInstance__c = instance.Id,
        CKR_ChecklistInstanceItem__c = item.Id,
        CKR_EventType__c = 'ItemCompleted'
      );
    insert event;
    CKR_ChecklistAuditEvent__c cascade =
      new CKR_ChecklistAuditEvent__c(
        CKR_ChecklistInstance__c = instance.Id,
        CKR_EventType__c = 'ItemCompleted'
      );
    insert cascade;
    CKR_ChecklistGateRule__c rule =
      new CKR_ChecklistGateRule__c(
        CKR_ChecklistTemplateVersion__c = fixture.versionId,
        CKR_ProtectedActionType__c = 'AnyFieldValueChange',
        CKR_TargetFieldApiName__c = 'Rating'
      );
    insert rule;
    CKR_GateBypassEvent__c bypass =
      new CKR_GateBypassEvent__c(
        CKR_GateRule__c = rule.Id,
        CKR_RecordId__c = '001000000000001AAA',
        CKR_Source__c = 'CustomPermission'
      );
    insert bypass;
    System.runAs(runner) {
      System.Assert.isTrue(
          FeatureManagement.checkPermission('CKR_Audit_Maintenance')
        );
      delete item;
      System.Assert.areEqual(
          0,
          [
            SELECT COUNT()
            FROM CKR_ChecklistInstanceItem__c
            WHERE Id = :item.Id
          ],
          'Maintenance permits deliberate item deletion.'
        );
      System.Assert.isNull(
          [
            SELECT CKR_ChecklistInstanceItem__c
            FROM CKR_ChecklistAuditEvent__c
            WHERE Id = :event.Id
          ]
            .CKR_ChecklistInstanceItem__c,
          'Authorized item deletion clears the SetNull lookup but retains the event.'
        );
      // Send only the changed field: the in-memory record carries the
      // master-detail parent and the cleared item lookup.
      update new CKR_ChecklistAuditEvent__c(
        Id = event.Id,
        CKR_Details__c = 'Authorized correction'
      );
      delete event;
      delete instance;
      System.Assert.areEqual(
          0,
          [
            SELECT COUNT()
            FROM CKR_ChecklistAuditEvent__c
            WHERE Id = :cascade.Id
          ]
        );
      System.Assert.isFalse(
          Database.delete(rule, false).isSuccess(),
          'Maintenance must explicitly remove bypass history before deleting its rule.'
        );
      System.Assert.areEqual(
          rule.Id,
          [
            SELECT CKR_GateRule__c
            FROM CKR_GateBypassEvent__c
            WHERE Id = :bypass.Id
          ]
            .CKR_GateRule__c,
          'Maintenance cannot silently clear the rule link.'
        );
      update new CKR_GateBypassEvent__c(
        Id = bypass.Id,
        CKR_Details__c = 'Authorized correction'
      );
      delete bypass;
      delete rule;
      System.Assert.areEqual(
          0,
          [SELECT COUNT() FROM CKR_ChecklistGateRule__c WHERE Id = :rule.Id],
          'After explicit history deletion a Draft rule is deletable.'
        );
      System.Assert.areEqual(
          0,
          [SELECT COUNT() FROM CKR_GateBypassEvent__c WHERE Id = :bypass.Id]
        );
    }
  }
}
