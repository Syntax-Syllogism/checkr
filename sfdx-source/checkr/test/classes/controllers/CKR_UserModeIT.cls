@IsTest
private class CKR_UserModeIT {
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
        Username = suffix + '@ckr-usermode.example.com'
      );
    // Running as the current user in its own context avoids MIXED_DML_OPERATION
    // between the user/assignment setup rows and the checklist data.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert testUser;
      insert new PermissionSetAssignment(
        AssigneeId = testUser.Id,
        PermissionSetId =
          [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName].Id
      );
    }
    return testUser;
  }

  private static CKR_ChecklistInstanceItem__c insertItem(Id instanceId) {
    CKR_ChecklistInstanceItem__c itemRecord =
      new CKR_ChecklistInstanceItem__c(
        CKR_ChecklistInstance__c = instanceId,
        CKR_SourceType__c = 'Template',
        CKR_Label__c = 'Capture sign-off',
        CKR_ExplanationInputType__c = 'Text',
        CKR_Required__c = true,
        CKR_Completed__c = false,
        CKR_CheckboxValue__c = false,
        CKR_SortOrder__c = 1
      );
    insert itemRecord;
    return itemRecord;
  }

  @IsTest
  static void ckrUser_completesItem_integrationHappyPath() {
    CKR_TestDataFactory.ChecklistInstanceSpec instanceSpec =
      new CKR_TestDataFactory.ChecklistInstanceSpec();
    instanceSpec.accountName = 'User Mode Parent';
    instanceSpec.templateName = 'User Mode Template';
    instanceSpec.requiredItemCount = 1;
    instanceSpec.completedRequiredItemCount = 0;
    instanceSpec.isComplete = false;
    instanceSpec.isOverdue = false;
    instanceSpec.percentComplete = 0;
    CKR_TestDataFactory.ChecklistInstanceFixture fixture =
      CKR_TestDataFactory.createAccountChecklistInstance(instanceSpec);
    CKR_ChecklistInstanceItem__c itemRecord = insertItem(fixture.instanceId);
    User runner = userWith('CKR_User', 'ckrusr');
    // Parent ownership grants access even when Account OWD is Private.
    update new Account(Id = fixture.accountId, OwnerId = runner.Id);

    System.runAs(runner) {
      CKR_ChecklistItemUpdateRequest actionRequest =
        new CKR_ChecklistItemUpdateRequest();
      actionRequest.checklistItemId = itemRecord.Id;
      actionRequest.checkboxValue = true;
      actionRequest.explanation = 'Signed';
      actionRequest.explanationRequired = false;
      CKR_ChecklistViewerController.updateChecklistItem(actionRequest);
    }

    System.Assert.isTrue(
        [
          SELECT CKR_Completed__c
          FROM CKR_ChecklistInstanceItem__c
          WHERE Id = :itemRecord.Id
        ]
          .CKR_Completed__c,
        'A CKR_User should be able to complete an item.'
      );
    System.Assert.isTrue(
        [SELECT COUNT() FROM CKR_ChecklistAuditEvent__c] > 0,
        'The application should write audit events on the CKR_User\'s behalf.'
      );
  }

  @IsTest
  static void ckrReadOnly_cannotCompleteItem_integrationHappyPath() {
    CKR_TestDataFactory.ChecklistInstanceSpec instanceSpec =
      new CKR_TestDataFactory.ChecklistInstanceSpec();
    instanceSpec.accountName = 'Read Only Parent';
    instanceSpec.templateName = 'Read Only Template';
    instanceSpec.requiredItemCount = 1;
    instanceSpec.completedRequiredItemCount = 0;
    instanceSpec.isComplete = false;
    instanceSpec.isOverdue = false;
    instanceSpec.percentComplete = 0;
    CKR_TestDataFactory.ChecklistInstanceFixture fixture =
      CKR_TestDataFactory.createAccountChecklistInstance(instanceSpec);
    CKR_ChecklistInstanceItem__c itemRecord = insertItem(fixture.instanceId);
    User runner = userWith('CKR_ReadOnly', 'ckrro');
    // Parent ownership grants access even when Account OWD is Private.
    update new Account(Id = fixture.accountId, OwnerId = runner.Id);

    Boolean blocked = false;
    System.runAs(runner) {
      try {
        CKR_ChecklistItemUpdateRequest actionRequest2 =
          new CKR_ChecklistItemUpdateRequest();
        actionRequest2.checklistItemId = itemRecord.Id;
        actionRequest2.checkboxValue = true;
        actionRequest2.explanation = 'Signed';
        actionRequest2.explanationRequired = false;
        CKR_ChecklistViewerController.updateChecklistItem(actionRequest2);
      } catch (Exception ex) {
        blocked = true;
      }
    }

    System.Assert.isTrue(blocked, 'A CKR_ReadOnly user must not write items.');
    System.Assert.isFalse(
        [
          SELECT CKR_Completed__c
          FROM CKR_ChecklistInstanceItem__c
          WHERE Id = :itemRecord.Id
        ]
          .CKR_Completed__c,
        'The item should be unchanged.'
      );
  }

  @IsTest
  static void ckrUser_cannotInsertAuditEventDirectly_integrationHappyPath() {
    User runner = userWith('CKR_User', 'ckrusr2');
    Boolean blocked = false;
    System.runAs(runner) {
      try {
        Database.insert(
          new List<SObject>{ new CKR_ChecklistAuditEvent__c() },
          true,
          AccessLevel.USER_MODE
        );
      } catch (Exception ex) {
        blocked = true;
      }
    }
    System.Assert.isTrue(blocked, 'Users cannot forge audit events.');
  }

  @IsTest
  static void ckrUser_createsChecklistInstance_integrationHappyPath() {
    Account account = new Account(Name = 'User Mode Create');
    insert account;
    CKR_TestDataFactory.TemplateFixture templateFixture =
      CKR_TestDataFactory.createPublishedAccountTemplate(
        'User Mode Create Template'
      );
    User runner = userWith('CKR_User', 'ckrcrt');
    update new Account(Id = account.Id, OwnerId = runner.Id);

    CKR_ChecklistInstanceCreateResult result;
    System.runAs(runner) {
      CKR_ChecklistInstanceCreateRequest actionRequest3 =
        new CKR_ChecklistInstanceCreateRequest();
      actionRequest3.templateId = templateFixture.templateId;
      actionRequest3.parentRecordId = account.Id;
      actionRequest3.parentObjectApiName = 'Account';
      actionRequest3.dueDate = Date.today().addDays(7);
      result =
        CKR_ChecklistCreateActionController.createChecklistAction(
          actionRequest3
        );
    }

    System.Assert.isTrue(
        result.success,
        'A CKR_User should be able to create an instance.'
      );
    System.Assert.areEqual(
        1,
        [
          SELECT COUNT()
          FROM CKR_ChecklistInstance__c
          WHERE Id = :result.checklistInstanceId
        ],
        'The instance should be persisted.'
      );
    System.Assert.isTrue(
        [
          SELECT COUNT()
          FROM CKR_ChecklistInstanceItem__c
          WHERE CKR_ChecklistInstance__c = :result.checklistInstanceId
        ]
        > 0,
        'Template items should be created with the instance.'
      );
  }

  @IsTest
  static void ckrUser_addsEditsButCannotRemoveAuditedAdHocItem_integrationHappyPath() {
    CKR_TestDataFactory.ChecklistInstanceSpec instanceSpec =
      new CKR_TestDataFactory.ChecklistInstanceSpec();
    instanceSpec.accountName = 'Ad Hoc Parent';
    instanceSpec.templateName = 'Ad Hoc Template';
    instanceSpec.requiredItemCount = 1;
    instanceSpec.completedRequiredItemCount = 0;
    instanceSpec.isComplete = false;
    instanceSpec.isOverdue = false;
    instanceSpec.percentComplete = 0;
    CKR_TestDataFactory.ChecklistInstanceFixture fixture =
      CKR_TestDataFactory.createAccountChecklistInstance(instanceSpec);
    User runner = userWith('CKR_User', 'ckradh');
    // Parent ownership grants access even when Account OWD is Private.
    update new Account(Id = fixture.accountId, OwnerId = runner.Id);

    System.runAs(runner) {
      CKR_AdHocItemRequest actionRequest4 = new CKR_AdHocItemRequest();
      actionRequest4.checklistInstanceId = fixture.instanceId;
      actionRequest4.label = 'Ad hoc step';
      actionRequest4.explanationInputType = 'Text';
      actionRequest4.explanationRequired = false;
      CKR_ChecklistViewerController.addAdHocItem(actionRequest4);
    }
    CKR_ChecklistInstanceItem__c adHoc = [
      SELECT Id, CKR_Label__c
      FROM CKR_ChecklistInstanceItem__c
      WHERE
        CKR_ChecklistInstance__c = :fixture.instanceId
        AND CKR_SourceType__c = 'AdHoc'
    ];
    System.Assert.areEqual('Ad hoc step', adHoc.CKR_Label__c);

    System.runAs(runner) {
      CKR_ChecklistItemUpdateRequest actionRequest5 =
        new CKR_ChecklistItemUpdateRequest();
      actionRequest5.checklistItemId = adHoc.Id;
      actionRequest5.checkboxValue = false;
      actionRequest5.label = 'Renamed step';
      actionRequest5.explanationInputType = 'Text';
      actionRequest5.explanationRequired = false;
      CKR_ChecklistViewerController.updateChecklistItem(actionRequest5);
    }
    System.Assert.areEqual(
        'Renamed step',
        [
          SELECT CKR_Label__c
          FROM CKR_ChecklistInstanceItem__c
          WHERE Id = :adHoc.Id
        ]
          .CKR_Label__c,
        'A CKR_User should be able to edit an ad hoc item.'
      );

    List<CKR_ChecklistAuditEvent__c> history = [
      SELECT Id
      FROM CKR_ChecklistAuditEvent__c
      WHERE CKR_ChecklistInstanceItem__c = :adHoc.Id
    ];
    System.Assert.isFalse(
        history.isEmpty(),
        'The item has linked history before removal.'
      );
    System.runAs(runner) {
      Savepoint requestStart = Database.setSavepoint();
      try {
        CKR_ChecklistViewerController.removeAdHocItem(adHoc.Id);
        System.Assert.fail('Audited item deletion must require maintenance.');
      } catch (DmlException error) {
        // Simulate the failed Aura request's transaction rollback after catching it here.
        Database.rollback(requestStart);
        System.Assert.isTrue(
            error.getMessage().contains(CKR_AuditRecordGuard.MESSAGE)
          );
      }
    }
    System.Assert.areEqual(
        1,
        [SELECT COUNT() FROM CKR_ChecklistInstanceItem__c WHERE Id = :adHoc.Id],
        'A CKR_User cannot delete an audited ad hoc item.'
      );
    System.Assert.areEqual(
        history.size(),
        [
          SELECT COUNT()
          FROM CKR_ChecklistAuditEvent__c
          WHERE CKR_ChecklistInstanceItem__c = :adHoc.Id
        ],
        'Blocked removal preserves every audit link.'
      );
    System.Assert.areEqual(
        0,
        [
          SELECT COUNT()
          FROM CKR_ChecklistAuditEvent__c
          WHERE
            CKR_ChecklistInstance__c = :fixture.instanceId
            AND CKR_EventType__c = 'AdHocItemRemoved'
        ],
        'Rejected removal must not record a successful removal.'
      );
  }

  @IsTest
  static void ckrUser_completingItem_rollsUpInstanceStatus_integrationHappyPath() {
    CKR_TestDataFactory.ChecklistInstanceSpec instanceSpec =
      new CKR_TestDataFactory.ChecklistInstanceSpec();
    instanceSpec.accountName = 'Rollup Parent';
    instanceSpec.templateName = 'Rollup Template';
    instanceSpec.requiredItemCount = 1;
    instanceSpec.completedRequiredItemCount = 0;
    instanceSpec.isComplete = false;
    instanceSpec.isOverdue = false;
    instanceSpec.percentComplete = 0;
    CKR_TestDataFactory.ChecklistInstanceFixture fixture =
      CKR_TestDataFactory.createAccountChecklistInstance(instanceSpec);
    CKR_ChecklistInstanceItem__c itemRecord = insertItem(fixture.instanceId);
    User runner = userWith('CKR_User', 'ckrroll');
    // Parent ownership grants access even when Account OWD is Private.
    update new Account(Id = fixture.accountId, OwnerId = runner.Id);

    System.runAs(runner) {
      CKR_ChecklistItemUpdateRequest actionRequest6 =
        new CKR_ChecklistItemUpdateRequest();
      actionRequest6.checklistItemId = itemRecord.Id;
      actionRequest6.checkboxValue = true;
      actionRequest6.explanation = 'Signed';
      actionRequest6.explanationRequired = false;
      CKR_ChecklistViewerController.updateChecklistItem(actionRequest6);
    }

    CKR_ChecklistInstance__c instanceRecord = [
      SELECT CKR_IsComplete__c, CKR_PercentComplete__c
      FROM CKR_ChecklistInstance__c
      WHERE Id = :fixture.instanceId
    ];
    System.Assert.isTrue(
        instanceRecord.CKR_IsComplete__c,
        'The application should roll the derived status up on the user\'s behalf.'
      );
    System.Assert.areEqual(100, instanceRecord.CKR_PercentComplete__c);
  }

  @IsTest
  static void ckrUser_cannotSetIsCompleteDirectly_integrationHappyPath() {
    CKR_TestDataFactory.ChecklistInstanceSpec instanceSpec =
      new CKR_TestDataFactory.ChecklistInstanceSpec();
    instanceSpec.accountName = 'Forgery Parent';
    instanceSpec.templateName = 'Forgery Template';
    instanceSpec.requiredItemCount = 1;
    instanceSpec.completedRequiredItemCount = 0;
    instanceSpec.isComplete = false;
    instanceSpec.isOverdue = false;
    instanceSpec.percentComplete = 0;
    CKR_TestDataFactory.ChecklistInstanceFixture fixture =
      CKR_TestDataFactory.createAccountChecklistInstance(instanceSpec);
    insertItem(fixture.instanceId);
    User runner = userWith('CKR_User', 'ckrfrg');
    // Parent ownership grants access even when Account OWD is Private.
    update new Account(Id = fixture.accountId, OwnerId = runner.Id);

    Boolean blocked = false;
    System.runAs(runner) {
      try {
        Database.update(
          new List<SObject>{
            new CKR_ChecklistInstance__c(
              Id = fixture.instanceId,
              CKR_IsComplete__c = true
            )
          },
          true,
          AccessLevel.USER_MODE
        );
      } catch (Exception ex) {
        blocked = true;
      }
    }

    System.Assert.isTrue(blocked, 'Users cannot forge derived gate state.');
    System.Assert.isFalse(
        [
          SELECT CKR_IsComplete__c
          FROM CKR_ChecklistInstance__c
          WHERE Id = :fixture.instanceId
        ]
          .CKR_IsComplete__c,
        'The instance must stay incomplete.'
      );
  }

  @IsTest
  static void ckrUser_cannotForgeItemGateFields_integrationHappyPath() {
    CKR_TestDataFactory.ChecklistInstanceSpec instanceSpec =
      new CKR_TestDataFactory.ChecklistInstanceSpec();
    instanceSpec.accountName = 'Item Forgery Parent';
    instanceSpec.templateName = 'Item Forgery Template';
    instanceSpec.requiredItemCount = 1;
    instanceSpec.completedRequiredItemCount = 0;
    instanceSpec.isComplete = false;
    instanceSpec.isOverdue = false;
    instanceSpec.percentComplete = 0;
    CKR_TestDataFactory.ChecklistInstanceFixture fixture =
      CKR_TestDataFactory.createAccountChecklistInstance(instanceSpec);
    CKR_ChecklistInstanceItem__c completionItem =
      insertItem(fixture.instanceId);
    CKR_ChecklistInstanceItem__c requiredItem = insertItem(fixture.instanceId);
    CKR_ChecklistInstanceItem__c sourceItem = insertItem(fixture.instanceId);
    User runner = userWith('CKR_User', 'ckritm');

    List<CKR_ChecklistInstanceItem__c> forgeries =
      new List<CKR_ChecklistInstanceItem__c>{
        new CKR_ChecklistInstanceItem__c(
          Id = completionItem.Id,
          CKR_Completed__c = true
        ),
        new CKR_ChecklistInstanceItem__c(
          Id = requiredItem.Id,
          CKR_Required__c = false
        ),
        new CKR_ChecklistInstanceItem__c(
          Id = sourceItem.Id,
          CKR_SourceType__c = 'AdHoc'
        )
      };
    List<Database.SaveResult> attempts;
    System.runAs(runner) {
      attempts = Database.update(forgeries, false, AccessLevel.USER_MODE);
    }
    System.Assert.areEqual(forgeries.size(), attempts.size());
    for (Database.SaveResult attempt : attempts) {
      System.Assert.isFalse(
          attempt.isSuccess(),
          'Users cannot directly write gate-driving item fields.'
        );
    }

    Set<Id> itemIds =
      new Map<Id, CKR_ChecklistInstanceItem__c>(forgeries).keySet();
    List<CKR_ChecklistInstanceItem__c> reloaded = [
      SELECT CKR_Completed__c, CKR_Required__c, CKR_SourceType__c
      FROM CKR_ChecklistInstanceItem__c
      WHERE Id IN :itemIds
    ];
    System.Assert.areEqual(forgeries.size(), reloaded.size());
    for (CKR_ChecklistInstanceItem__c item : reloaded) {
      System.Assert.isFalse(item.CKR_Completed__c);
      System.Assert.isTrue(item.CKR_Required__c);
      System.Assert.areEqual('Template', item.CKR_SourceType__c);
    }
  }

  @IsTest
  static void ckrUser_canReadEverySelectorField_integrationHappyPath() {
    Map<String, List<String>> selectorFields =
      new Map<String, List<String>>{
        'CKR_ChecklistInstanceItem__c' => new List<String>{
          'CKR_SourceType__c',
          'CKR_Required__c',
          'CKR_Label__c',
          'CKR_ExplanationRequired__c',
          'CKR_ExplanationInputType__c',
          'CKR_ExplanationPicklistValues__c',
          'CKR_AssigneeUser__c',
          'CKR_CheckboxValue__c',
          'CKR_Explanation__c',
          'CKR_Completed__c',
          'CKR_SortOrder__c'
        },
        'CKR_ChecklistInstance__c' => new List<String>{
          'CKR_ParentRecordId__c',
          'CKR_ChecklistTemplate__c',
          'CKR_ChecklistTemplateVersion__c',
          'CKR_IsComplete__c',
          'CKR_IsOverdue__c',
          'CKR_PercentComplete__c',
          'CKR_DueDate__c',
          'CKR_UniqueKey__c'
        },
        'CKR_ChecklistTemplateVersion__c' => new List<String>{
          'CKR_Status__c',
          'CKR_CompletionAccessMode__c',
          'CKR_CustomPermissionDeveloperName__c',
          'CKR_VersionNumber__c',
          'CKR_Description__c'
        },
        'CKR_ChecklistTemplate__c' => new List<String>{
          'CKR_Active__c',
          'CKR_TargetObjectApiName__c',
          'CKR_CurrentPublishedVersion__c',
          'CKR_Description__c'
        },
        'CKR_ChecklistTemplateItem__c' => new List<String>{
          'CKR_Label__c',
          'CKR_Required__c',
          'CKR_Active__c',
          'CKR_ExplanationRequired__c',
          'CKR_ExplanationInputType__c',
          'CKR_ExplanationPicklistValues__c',
          'CKR_AssigneeUser__c',
          'CKR_SortOrder__c'
        }
      };
    User runner = userWith('CKR_User', 'ckrfls');

    List<String> unreadable = new List<String>();
    System.runAs(runner) {
      List<Schema.DescribeSObjectResult> objects =
        Schema.describeSObjects(
          new List<String>(selectorFields.keySet()),
          SObjectDescribeOptions.DEFERRED
        );
      for (Schema.DescribeSObjectResult objectInfo : objects) {
        String objectName = objectInfo.getName();
        Map<String, Schema.SObjectField> fields = objectInfo.fields.getMap();
        for (String fieldName : selectorFields.get(objectName)) {
          if (!fields.get(fieldName).getDescribe().isAccessible()) {
            unreadable.add(objectName + '.' + fieldName);
          }
        }
      }
    }

    System.Assert.isTrue(
        unreadable.isEmpty(),
        'CKR_User must be able to read every field the user-mode selectors query: '
        + String.join(unreadable, ', ')
      );
  }
}
