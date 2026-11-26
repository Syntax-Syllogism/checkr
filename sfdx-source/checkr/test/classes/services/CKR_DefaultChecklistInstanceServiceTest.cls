// In-memory unit tests exercise logic and stubbed dependencies without database access.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_DefaultChecklistInstanceServiceTest {
  private static final Id TEMPLATE_ID =
    CKR_TestRecords.fakeId(CKR_ChecklistTemplate__c.SObjectType, 1);
  private static final Id VERSION_ID =
    CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 1);

  private static CKR_Mocks.MethodRecorder itemDml;

  @IsTest
  static void createFromTemplate_snapshotsItemAssigneeAndExplanationMetadata() {
    CKR_ChecklistTemplateItem__c templateItem = templateItem();
    CKR_Mocks.MethodRecorder selector =
      selector(templateVersion(), templateItem);
    CKR_Mocks.MethodRecorder dml = installDml();
    installSelector(selector);

    try {
      CKR_ChecklistInstanceCreateRequest request = validRequest();
      Integer queriesBefore = Limits.getQueries();
      Integer dmlBefore = Limits.getDmlStatements();

      CKR_ChecklistInstanceCreateResult result =
        new CKR_DefaultChecklistInstanceService().createFromTemplate(request);

      System.Assert.areEqual(
          queriesBefore,
          Limits.getQueries(),
          'Stubbed selectors should keep the unit test off the database.'
        );
      System.Assert.areEqual(
          dmlBefore,
          Limits.getDmlStatements(),
          'Stubbed DML should keep the unit test off the database.'
        );
      System.Assert.isTrue(
          result.success,
          'Published templates should create instances.'
        );
      System.Assert.areEqual(
          1,
          dml.callCount('doInsert'),
          'The service should insert the instance in user mode.'
        );
      System.Assert.areEqual(
          1,
          itemDml.callCount('doInsert'),
          'The service should insert template items in system mode.'
        );
      System.Assert.areEqual(
          CKR_DmlMode.ALL_OR_NONE,
          dml.argumentsAt('doInsert', 0)[1],
          'Instance inserts should be all-or-none.'
        );
      System.Assert.areEqual(
          CKR_DmlMode.ALL_OR_NONE,
          itemDml.argumentsAt('doInsert', 0)[1],
          'Item inserts should be all-or-none.'
        );
      CKR_ChecklistInstance__c inserted =
        (CKR_ChecklistInstance__c) (
          (List<SObject>) dml.argumentsAt('doInsert', 0)[0]
        )[0];
      System.Assert.areEqual(
          String.valueOf(request.parentRecordId)
          + '|'
          + String.valueOf(TEMPLATE_ID),
          inserted.CKR_UniqueKey__c,
          'The unique key should no longer include an assignee segment.'
        );

      List<SObject> items =
        (List<SObject>) itemDml.argumentsAt('doInsert', 0)[0];
      System.Assert.areEqual(
          1,
          items.size(),
          'The service should snapshot one active template item.'
        );
      CKR_ChecklistInstanceItem__c item =
        (CKR_ChecklistInstanceItem__c) items[0];
      System.Assert.areEqual(
          inserted.Id,
          item.CKR_ChecklistInstance__c,
          'Items should attach to the inserted instance.'
        );
      System.Assert.areEqual(
          templateItem.CKR_AssigneeUser__c,
          item.CKR_AssigneeUser__c,
          'Template item assignee should snapshot to the instance item.'
        );
      System.Assert.areEqual(
          'Picklist',
          item.CKR_ExplanationInputType__c,
          'Explanation input type should snapshot from the template item.'
        );
      System.Assert.areEqual(
          'Approved\nRejected',
          item.CKR_ExplanationPicklistValues__c,
          'Explanation picklist values should snapshot when the input type is Picklist.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void createFromTemplate_blocksDuplicateByParentAndTemplate() {
    CKR_Mocks.MethodRecorder selector =
      selector(templateVersion(), templateItem())
        .when('existingInstanceExists', true);
    CKR_Mocks.MethodRecorder dml = installDml();
    installSelector(selector);

    try {
      CKR_ChecklistInstanceCreateResult result =
        new CKR_DefaultChecklistInstanceService().createFromTemplate(
          validRequest()
        );

      System.Assert.isFalse(
          result.success,
          'Duplicate instances should be blocked.'
        );
      System.Assert.areEqual(
          'A checklist instance already exists for this record and template.',
          result.messages[0],
          'Duplicate messaging should match the new instance-level uniqueness rule.'
        );
      System.Assert.areEqual(
          0,
          dml.callCount('doInsert'),
          'Duplicates should be rejected before any insert.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void createFromTemplate_returnsValidationMessagesBeforeSelectors() {
    CKR_ChecklistInstanceCreateResult result =
      new CKR_DefaultChecklistInstanceService().createFromTemplate(
        new CKR_ChecklistInstanceCreateRequest()
      );

    System.Assert.isFalse(
        result.success,
        'Invalid creation requests should not succeed.'
      );
    System.Assert.areEqual(
        3,
        result.messages.size(),
        'Missing parent record, parent object, and template fields should all be reported.'
      );
    System.Assert.isTrue(
        result.messages.contains('A parent record is required.'),
        'Validation should report the missing parent record.'
      );
    System.Assert.isTrue(
        result.messages.contains('A parent object API name is required.'),
        'Validation should report the missing parent object API name.'
      );
    System.Assert.isTrue(
        result.messages.contains(
            'A checklist template or published template version is required.'
          ),
        'Validation should report the missing template selection.'
      );
  }

  @IsTest
  static void createFromTemplate_blocksUnpublishedTemplateVersion() {
    installSelector(selector(templateVersion('Draft', true), templateItem()));
    CKR_Mocks.MethodRecorder dml = installDml();

    try {
      CKR_ChecklistInstanceCreateResult result =
        new CKR_DefaultChecklistInstanceService().createFromTemplate(
          validRequest()
        );

      System.Assert.isFalse(
          result.success,
          'Draft template versions should not create checklist instances.'
        );
      System.Assert.areEqual(
          'Only published checklist template versions can create checklist instances.',
          result.messages[0],
          'Draft template versions should return the expected message.'
        );
      System.Assert.areEqual(0, dml.callCount('doInsert'), 'No DML expected.');
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void createFromTemplate_blocksInactiveTemplate() {
    installSelector(
      selector(templateVersion('Published', false), templateItem())
    );
    CKR_Mocks.MethodRecorder dml = installDml();

    try {
      CKR_ChecklistInstanceCreateResult result =
        new CKR_DefaultChecklistInstanceService().createFromTemplate(
          validRequest()
        );

      System.Assert.isFalse(
          result.success,
          'Inactive templates should not create checklist instances.'
        );
      System.Assert.areEqual(
          'The selected checklist template is inactive.',
          result.messages[0],
          'Inactive templates should return the expected message.'
        );
      System.Assert.areEqual(0, dml.callCount('doInsert'), 'No DML expected.');
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void createFromTemplate_blocksWrongParentObject() {
    installSelector(selector(templateVersion(), templateItem()));
    CKR_Mocks.MethodRecorder dml = installDml();

    try {
      CKR_ChecklistInstanceCreateRequest request = validRequest();
      request.parentObjectApiName = 'Opportunity';

      CKR_ChecklistInstanceCreateResult result =
        new CKR_DefaultChecklistInstanceService().createFromTemplate(request);

      System.Assert.isFalse(
          result.success,
          'Templates should only create instances for their configured parent object.'
        );
      System.Assert.areEqual(
          'The selected checklist template does not support the requested parent object.',
          result.messages[0],
          'Wrong-object requests should return the expected message.'
        );
      System.Assert.areEqual(0, dml.callCount('doInsert'), 'No DML expected.');
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void createFromTemplate_marksZeroRequiredItemsComplete() {
    CKR_ChecklistTemplateItem__c optionalItem = templateItem();
    optionalItem.CKR_Required__c = false;
    installSelector(selector(templateVersion(), optionalItem));
    CKR_Mocks.MethodRecorder dml = installDml();
    CKR_Mocks.MethodRecorder systemDml = new CKR_Mocks.MethodRecorder();
    CKR_AppFactory.setMock(
      CKR_ISystemDmlGateway.class,
      CKR_Mocks.stub(CKR_ISystemDmlGateway.class, systemDml)
    );

    try {
      CKR_ChecklistInstanceCreateRequest request = validRequest();
      request.dueDate = Date.today().addDays(-1);

      CKR_ChecklistInstanceCreateResult result =
        new CKR_DefaultChecklistInstanceService().createFromTemplate(request);

      CKR_ChecklistInstance__c inserted =
        (CKR_ChecklistInstance__c) (
          (List<SObject>) dml.argumentsAt('doInsert', 0)[0]
        )[0];
      System.Assert.isTrue(
          result.success,
          'Templates with no required items should still create instances.'
        );
      System.Assert.isFalse(
          inserted.CKR_IsComplete__c == true,
          'The user-mode insert must not carry the derived complete flag.'
        );
      CKR_ChecklistInstance__c completed =
        (CKR_ChecklistInstance__c) (
          (List<SObject>) systemDml.argumentsAt('doUpdate', 0)[0]
        )[0];
      System.Assert.isTrue(
          completed.CKR_IsComplete__c,
          'Instances with no required items should start complete, set in system mode.'
        );
      System.Assert.areEqual(
          100,
          inserted.CKR_PercentComplete__c,
          'Instances with no required items should start at 100 percent.'
        );
      System.Assert.isFalse(
          inserted.CKR_IsOverdue__c,
          'Complete instances should not be marked overdue even when due date is past.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  private static CKR_Mocks.MethodRecorder selector(
    CKR_ChecklistTemplateVersion__c version,
    CKR_ChecklistTemplateItem__c item
  ) {
    return new CKR_Mocks.MethodRecorder()
      .when('selectTemplateVersionById', version)
      .when('selectCurrentPublishedTemplateVersion', version)
      .when(
        'selectActiveTemplateItemsByVersionId',
        new List<CKR_ChecklistTemplateItem__c>{ item }
      )
      .when('existingInstanceExists', false);
  }

  private static void installSelector(CKR_Mocks.MethodRecorder selector) {
    CKR_AppFactory.setMock(
      CKR_IChecklistInstanceSelector.class,
      CKR_Mocks.stub(CKR_IChecklistInstanceSelector.class, selector)
    );
  }

  private static CKR_Mocks.MethodRecorder installDml() {
    CKR_Mocks.MethodRecorder dml =
      new CKR_Mocks.MethodRecorder().assignsIds('doInsert');
    CKR_AppFactory.setMock(
      CKR_IDmlGateway.class,
      CKR_Mocks.stub(CKR_IDmlGateway.class, dml)
    );
    itemDml = new CKR_Mocks.MethodRecorder().assignsIds('doInsert');
    CKR_AppFactory.setMock(
      CKR_ISystemDmlGateway.class,
      CKR_Mocks.stub(CKR_ISystemDmlGateway.class, itemDml)
    );
    return dml;
  }

  private static CKR_ChecklistTemplateVersion__c templateVersion() {
    return templateVersion('Published', true);
  }

  private static CKR_ChecklistTemplateVersion__c templateVersion(
    String status,
    Boolean templateActive
  ) {
    return (CKR_ChecklistTemplateVersion__c) CKR_TestRecords.build(
      CKR_ChecklistTemplateVersion__c.SObjectType,
      new Map<String, Object>{
        'Id' => VERSION_ID,
        'CKR_Status__c' => status,
        'CKR_ChecklistTemplate__c' => TEMPLATE_ID,
        'CKR_ChecklistTemplate__r.Id' => TEMPLATE_ID,
        'CKR_ChecklistTemplate__r.Name' => 'Account Launch',
        'CKR_ChecklistTemplate__r.CKR_Active__c' => templateActive,
        'CKR_ChecklistTemplate__r.CKR_TargetObjectApiName__c' => 'Account'
      }
    );
  }

  private static CKR_ChecklistTemplateItem__c templateItem() {
    return new CKR_ChecklistTemplateItem__c(
      Id = CKR_TestRecords.fakeId(CKR_ChecklistTemplateItem__c.SObjectType, 1),
      CKR_Label__c = 'Confirm billing contact',
      CKR_Required__c = true,
      CKR_ExplanationRequired__c = true,
      CKR_ExplanationInputType__c = 'Picklist',
      CKR_ExplanationPicklistValues__c = 'Approved\nRejected',
      CKR_AssigneeUser__c = CKR_TestRecords.fakeId(User.SObjectType, 1),
      CKR_SortOrder__c = 1
    );
  }

  private static CKR_ChecklistInstanceCreateRequest validRequest() {
    CKR_ChecklistInstanceCreateRequest request =
      new CKR_ChecklistInstanceCreateRequest();
    request.templateVersionId = VERSION_ID;
    request.parentRecordId = CKR_TestRecords.fakeId(Account.SObjectType, 1);
    request.parentObjectApiName = 'Account';
    return request;
  }
}
