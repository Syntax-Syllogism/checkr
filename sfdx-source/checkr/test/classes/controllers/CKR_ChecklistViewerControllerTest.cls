// In-memory unit tests exercise logic and stubbed dependencies without database access.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_ChecklistViewerControllerTest {
  private static CKR_Mocks.MethodRecorder systemDml;
  private static final Id INSTANCE_ID =
    CKR_TestRecords.fakeId(CKR_ChecklistInstance__c.SObjectType, 1);
  private static final Id ITEM_ID =
    CKR_TestRecords.fakeId(CKR_ChecklistInstanceItem__c.SObjectType, 1);

  @IsTest
  static void getRecordChecklists_mapsInstancesItemsAndPermissions() {
    CKR_Mocks.MethodRecorder viewer =
      new CKR_Mocks.MethodRecorder()
        .when(
          'selectInstancesByParentRecordId',
          new List<CKR_ChecklistInstance__c>{ viewerInstance() }
        )
        .when(
          'selectItemsByChecklistInstanceIds',
          new List<CKR_ChecklistInstanceItem__c>{ viewerItem() }
        );
    CKR_Mocks.MethodRecorder permissions = allowingPermissions();
    install(CKR_IChecklistViewerSelector.class, viewer);
    install(CKR_IChecklistPermissionService.class, permissions);

    try {
      Id parentRecordId = CKR_TestRecords.fakeId(Account.SObjectType, 1);
      Integer queriesBefore = Limits.getQueries();
      Integer dmlBefore = Limits.getDmlStatements();

      CKR_ChecklistViewerController.ChecklistViewerResponse response =
        CKR_ChecklistViewerController.getRecordChecklists(parentRecordId);

      System.Assert.areEqual(
          queriesBefore,
          Limits.getQueries(),
          'The stubbed selector should keep the unit test off the database.'
        );
      System.Assert.areEqual(
          dmlBefore,
          Limits.getDmlStatements(),
          'Reading checklists should not perform DML.'
        );
      System.Assert.areEqual(
          String.valueOf(parentRecordId),
          response.recordId,
          'Viewer responses should echo the requested parent record id.'
        );
      System.Assert.areEqual(
          String.valueOf(parentRecordId),
          (String) viewer.lastArguments('selectInstancesByParentRecordId')[0],
          'The selector should be asked for the requested parent record.'
        );
      System.Assert.areEqual(
          1,
          response.checklists.size(),
          'The stub selector should return one visible checklist.'
        );
      System.Assert.areEqual(
          'Account Launch',
          response.checklists[0].name,
          'Checklist names should prefer the template relationship name.'
        );
      System.Assert.areEqual(
          'Unassigned',
          response.checklists[0].ownerName,
          'Checklist owner names should fall back when no owner relationship is present.'
        );
      System.Assert.isTrue(
          response.checklists[0].canEditItems,
          'Allowed permission responses should mark checklist items editable.'
        );
      System.Assert.isNull(
          response.checklists[0].permissionMessage,
          'Editable checklists should not carry a permission warning.'
        );
      System.Assert.areEqual(
          1,
          response.checklists[0].items.size(),
          'Checklist items should attach to their parent checklist summary.'
        );
      System.Assert.areEqual(
          'Confirm billing contact',
          response.checklists[0].items[0].label,
          'Item labels should map from the selector result.'
        );
      System.Assert.isFalse(
          response.checklists[0].items[0].isAdHoc,
          'Template items should not be marked as ad hoc.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void getRecordChecklists_returnsEmptyForNullRecordId() {
    CKR_ChecklistViewerController.ChecklistViewerResponse response =
      CKR_ChecklistViewerController.getRecordChecklists(null);

    System.Assert.isNull(
        response.recordId,
        'Null record requests should return a null record id.'
      );
    System.Assert.areEqual(
        0,
        response.checklists.size(),
        'Null record requests should not query or return checklists.'
      );
  }

  @IsTest
  static void updateChecklistItem_requiresCheckboxAndExplanationForCompletion() {
    updateAdHocMetadataAndReopenCompletedItem();
    updateAdHocMetadataRejectsBlankLabelWithoutWriting();
    CKR_Mocks.MethodRecorder dml = new CKR_Mocks.MethodRecorder();
    CKR_Mocks.MethodRecorder audit = new CKR_Mocks.MethodRecorder();
    installMutation(mutationItem(), dml, audit);
    Id assigneeId = CKR_TestRecords.fakeId(User.SObjectType, 1);

    try {
      CKR_ChecklistItemUpdateRequest actionRequest =
        new CKR_ChecklistItemUpdateRequest();
      actionRequest.checklistItemId = ITEM_ID;
      actionRequest.checkboxValue = true;
      actionRequest.explanation = '';
      actionRequest.explanationRequired = false;
      actionRequest.assigneeUserId = assigneeId;
      CKR_ChecklistViewerController.updateChecklistItem(actionRequest);

      System.Assert.areEqual(
          CKR_DmlMode.ALL_OR_NONE,
          dml.argumentsAt('doUpdate', 0)[1],
          'Item updates should be all-or-none.'
        );
      System.Assert.isTrue(
          dml.callCount('doUpdate') >= 1,
          'Completing an item should update the item.'
        );
      System.Assert.areEqual(
          2,
          systemDml.callCount('doUpdate'),
          'Completion state and the derived instance rollup should be written in system mode.'
        );
      CKR_ChecklistInstanceItem__c updated =
        (CKR_ChecklistInstanceItem__c) (
          (List<SObject>) dml.argumentsAt('doUpdate', 0)[0]
        )[0];
      CKR_ChecklistInstanceItem__c completion =
        (CKR_ChecklistInstanceItem__c) (
          (List<SObject>) systemDml.argumentsAt('doUpdate', 0)[0]
        )[0];
      System.Assert.isTrue(
          completion.CKR_Completed__c,
          'Checkbox items with no required explanation should be complete when checked.'
        );
      System.Assert.areEqual(
          assigneeId,
          updated.CKR_AssigneeUser__c,
          'Viewer updates should persist the item assignee user.'
        );
      System.Assert.isTrue(
          auditEventTypes(audit).contains('ItemCompleted'),
          'Completing the item should create an ItemCompleted audit event.'
        );
      System.Assert.isTrue(
          auditEventTypes(audit).contains('AssigneeChanged'),
          'Changing the item assignee should create an AssigneeChanged audit event.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void updateChecklistItem_storesPicklistExplanationAsExplanation() {
    CKR_ChecklistInstanceItem__c item = mutationItem();
    item.CKR_ExplanationInputType__c = 'Picklist';
    item.CKR_ExplanationRequired__c = true;
    item.CKR_ExplanationPicklistValues__c = 'Approved\nRejected';
    CKR_Mocks.MethodRecorder dml = new CKR_Mocks.MethodRecorder();
    installMutation(item, dml, new CKR_Mocks.MethodRecorder());

    try {
      CKR_ChecklistItemUpdateRequest actionRequest2 =
        new CKR_ChecklistItemUpdateRequest();
      actionRequest2.checklistItemId = ITEM_ID;
      actionRequest2.checkboxValue = true;
      actionRequest2.explanation = 'Approved';
      actionRequest2.explanationRequired = false;
      CKR_ChecklistViewerController.updateChecklistItem(actionRequest2);

      System.Assert.isTrue(
          dml.callCount('doUpdate') >= 1,
          'Completing an item should update the item, then roll up the parent.'
        );
      CKR_ChecklistInstanceItem__c updated =
        (CKR_ChecklistInstanceItem__c) (
          (List<SObject>) dml.argumentsAt('doUpdate', 0)[0]
        )[0];
      System.Assert.areEqual(
          'Approved',
          updated.CKR_Explanation__c,
          'Picklist explanation selections should store in Explanation.'
        );
      CKR_ChecklistInstanceItem__c completion =
        (CKR_ChecklistInstanceItem__c) (
          (List<SObject>) systemDml.argumentsAt('doUpdate', 0)[0]
        )[0];
      System.Assert.isTrue(
          completion.CKR_Completed__c,
          'Required explanation should be satisfied by the selected explanation value.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void updateChecklistItem_rejectsMissingItemId() {
    try {
      CKR_ChecklistItemUpdateRequest actionRequest3 =
        new CKR_ChecklistItemUpdateRequest();
      actionRequest3.checkboxValue = true;
      actionRequest3.explanationRequired = false;
      CKR_ChecklistViewerController.updateChecklistItem(actionRequest3);
      System.Assert.fail('A missing item id should throw an Aura exception.');
    } catch (AuraHandledException ex) {
      System.Assert.isTrue(
          true,
          'The expected Aura exception was thrown for a missing item id.'
        );
    }
  }

  @IsTest
  static void updateChecklistItem_rejectsPermissionDeniedChecklist() {
    CKR_Mocks.MethodRecorder dml = new CKR_Mocks.MethodRecorder();
    installMutation(mutationItem(), dml, new CKR_Mocks.MethodRecorder());
    install(
      CKR_IChecklistPermissionService.class,
      new CKR_Mocks.MethodRecorder().when('canUpdateChecklistInstance', false)
    );

    try {
      CKR_ChecklistItemUpdateRequest actionRequest4 =
        new CKR_ChecklistItemUpdateRequest();
      actionRequest4.checklistItemId = ITEM_ID;
      actionRequest4.checkboxValue = true;
      actionRequest4.explanationRequired = false;
      CKR_ChecklistViewerController.updateChecklistItem(actionRequest4);
      System.Assert.fail(
          'Permission-denied checklist updates should throw an Aura exception.'
        );
    } catch (AuraHandledException ex) {
      System.Assert.areEqual(
          0,
          dml.callCount('doUpdate'),
          'Permission-denied updates should not write.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void addAdHocItem_insertsOptionalItemAndAuditEvent() {
    CKR_Mocks.MethodRecorder dml =
      new CKR_Mocks.MethodRecorder().assignsIds('doInsert');
    CKR_Mocks.MethodRecorder audit = new CKR_Mocks.MethodRecorder();
    installMutation(mutationItem(), dml, audit);

    try {
      CKR_AdHocItemRequest actionRequest5 = new CKR_AdHocItemRequest();
      actionRequest5.checklistInstanceId = INSTANCE_ID;
      actionRequest5.label = '  Follow up with buyer  ';
      actionRequest5.explanationInputType = 'Picklist';
      actionRequest5.explanationPicklistValues = 'Needed\nBlocked';
      actionRequest5.explanationRequired = true;
      actionRequest5.assigneeUserId =
        CKR_TestRecords.fakeId(User.SObjectType, 2);
      CKR_ChecklistViewerController.addAdHocItem(actionRequest5);

      System.Assert.areEqual(
          CKR_DmlMode.ALL_OR_NONE,
          dml.lastArguments('doInsert')[1],
          'Ad hoc inserts should be all-or-none.'
        );
      CKR_ChecklistInstanceItem__c inserted =
        (CKR_ChecklistInstanceItem__c) (
          (List<SObject>) dml.lastArguments('doInsert')[0]
        )[0];
      System.Assert.areEqual(
          'Follow up with buyer',
          inserted.CKR_Label__c,
          'Ad hoc item labels should be trimmed before insert.'
        );
      System.Assert.areEqual(
          'AdHoc',
          inserted.CKR_SourceType__c,
          'Inline-created items should be marked as ad hoc.'
        );
      System.Assert.isFalse(
          inserted.CKR_Required__c,
          'Ad hoc items should always be optional.'
        );
      System.Assert.areEqual(
          'Needed\nBlocked',
          inserted.CKR_ExplanationPicklistValues__c,
          'Picklist explanation options should be preserved for ad hoc items.'
        );
      System.Assert.isTrue(
          auditEventTypes(audit).contains('AdHocItemAdded'),
          'Adding an ad hoc item should create an audit event.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void addAdHocItem_rejectsBlankLabel() {
    try {
      CKR_AdHocItemRequest actionRequest6 = new CKR_AdHocItemRequest();
      actionRequest6.checklistInstanceId = INSTANCE_ID;
      actionRequest6.label = ' ';
      actionRequest6.explanationInputType = 'Text';
      actionRequest6.explanationRequired = false;
      CKR_ChecklistViewerController.addAdHocItem(actionRequest6);
      System.Assert.fail('Blank ad hoc labels should throw an Aura exception.');
    } catch (AuraHandledException ex) {
      System.Assert.isTrue(
          true,
          'The expected Aura exception was thrown for a blank ad hoc label.'
        );
    }
  }

  @IsTest
  static void removeAdHocItem_deletesOnlyAdHocItemsAndAudits() {
    CKR_ChecklistInstanceItem__c item = mutationItem();
    item.CKR_SourceType__c = 'AdHoc';
    CKR_Mocks.MethodRecorder dml = new CKR_Mocks.MethodRecorder();
    CKR_Mocks.MethodRecorder audit = new CKR_Mocks.MethodRecorder();
    installMutation(item, dml, audit);

    try {
      CKR_ChecklistViewerController.removeAdHocItem(ITEM_ID);

      System.Assert.areEqual(
          CKR_DmlMode.ALL_OR_NONE,
          dml.lastArguments('doDelete')[1],
          'Ad hoc deletes should be all-or-none.'
        );
      System.Assert.areEqual(
          ITEM_ID,
          ((List<SObject>) dml.lastArguments('doDelete')[0])[0].Id,
          'Removing an ad hoc item should delete the selected item.'
        );
      System.Assert.isTrue(
          auditEventTypes(audit).contains('AdHocItemRemoved'),
          'Removing an ad hoc item should create an audit event.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void removeAdHocItem_rejectsTemplateItems() {
    CKR_Mocks.MethodRecorder dml = new CKR_Mocks.MethodRecorder();
    installMutation(mutationItem(), dml, new CKR_Mocks.MethodRecorder());

    try {
      CKR_ChecklistViewerController.removeAdHocItem(ITEM_ID);
      System.Assert.fail('Template items should not be removable as ad hoc.');
    } catch (AuraHandledException ex) {
      System.Assert.areEqual(
          0,
          dml.callCount('doDelete'),
          'Template items should never be deleted.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void updateAdHocMetadataAndReopenCompletedItem() {
    CKR_ChecklistInstanceItem__c item = mutationItem();
    item.CKR_SourceType__c = 'AdHoc';
    item.CKR_Completed__c = true;
    item.CKR_CheckboxValue__c = true;
    item.CKR_Explanation__c = 'Previously approved';
    CKR_Mocks.MethodRecorder dml = new CKR_Mocks.MethodRecorder();
    CKR_Mocks.MethodRecorder audit = new CKR_Mocks.MethodRecorder();
    installMutation(item, dml, audit);
    try {
      CKR_ChecklistItemUpdateRequest actionRequest7 =
        new CKR_ChecklistItemUpdateRequest();
      actionRequest7.checklistItemId = ITEM_ID;
      actionRequest7.checkboxValue = false;
      actionRequest7.explanation = 'No';
      actionRequest7.assigneeUserId =
        CKR_TestRecords.fakeId(User.SObjectType, 7);
      actionRequest7.label = '  Reopened step  ';
      actionRequest7.explanationInputType = 'Picklist';
      actionRequest7.explanationPicklistValues = 'Yes\nNo';
      actionRequest7.explanationRequired = true;
      CKR_ChecklistViewerController.updateChecklistItem(actionRequest7);
      CKR_ChecklistInstanceItem__c changed =
        (CKR_ChecklistInstanceItem__c) (
          (List<SObject>) dml.lastArguments('doUpdate')[0]
        )[0];
      System.Assert.areEqual('Reopened step', changed.CKR_Label__c);
      System.Assert.areEqual('No', changed.CKR_Explanation__c);
      System.Assert.areEqual(
          actionRequest7.assigneeUserId,
          changed.CKR_AssigneeUser__c
        );
      System.Assert.areEqual('Picklist', changed.CKR_ExplanationInputType__c);
      System.Assert.areEqual(
          'Yes\nNo',
          changed.CKR_ExplanationPicklistValues__c
        );
      System.Assert.isTrue(changed.CKR_ExplanationRequired__c);
      CKR_ChecklistInstanceItem__c completion =
        (CKR_ChecklistInstanceItem__c) (
          (List<SObject>) systemDml.argumentsAt('doUpdate', 0)[0]
        )[0];
      System.Assert.isFalse(completion.CKR_Completed__c);
      System.Assert.isNull(completion.CKR_CompletedBy__c);
      System.Assert.isNull(completion.CKR_CompletedOn__c);
      System.Assert.areEqual(
          new Set<String>{
            'ItemUncompleted',
            'AnswerChanged',
            'ExplanationChanged',
            'AssigneeChanged'
          },
          auditEventTypes(audit),
          'Reopening preserves the complete change history.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void updateAdHocMetadataRejectsBlankLabelWithoutWriting() {
    CKR_ChecklistInstanceItem__c item = mutationItem();
    item.CKR_SourceType__c = 'AdHoc';
    CKR_Mocks.MethodRecorder dml = new CKR_Mocks.MethodRecorder();
    CKR_Mocks.MethodRecorder audit = new CKR_Mocks.MethodRecorder();
    installMutation(item, dml, audit);
    try {
      CKR_ChecklistItemUpdateRequest actionRequest8 =
        new CKR_ChecklistItemUpdateRequest();
      actionRequest8.checklistItemId = ITEM_ID;
      actionRequest8.checkboxValue = false;
      actionRequest8.label = ' ';
      actionRequest8.explanationInputType = 'Text';
      actionRequest8.explanationRequired = false;
      CKR_ChecklistViewerController.updateChecklistItem(actionRequest8);
      System.Assert.fail('Blank labels must be rejected on edit.');
    } catch (AuraHandledException expected) {
      System.Assert.areEqual(0, dml.callCount('doUpdate'));
      System.Assert.areEqual(0, systemDml.callCount('doUpdate'));
      System.Assert.areEqual(0, audit.callCount('record'));
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  private static void install(Type port, CKR_Mocks.MethodRecorder recorder) {
    CKR_AppFactory.setMock(port, CKR_Mocks.stub(port, recorder));
  }

  private static void installMutation(
    CKR_ChecklistInstanceItem__c item,
    CKR_Mocks.MethodRecorder dml,
    CKR_Mocks.MethodRecorder audit
  ) {
    CKR_Mocks.MethodRecorder mutation =
      new CKR_Mocks.MethodRecorder()
        .when('selectChecklistItemById', item)
        .when('selectChecklistInstanceById', rollupInstance())
        .when('selectNextAdHocSortOrder', (Decimal) 1)
        .when('selectChecklistInstanceForRollup', rollupInstance())
        .when('countRequiredTemplateItems', (Integer) 1)
        .when('countCompletedRequiredTemplateItems', (Integer) 1);
    install(CKR_IChecklistMutationSelector.class, mutation);
    install(CKR_IDmlGateway.class, dml);
    systemDml = new CKR_Mocks.MethodRecorder();
    install(CKR_ISystemDmlGateway.class, systemDml);
    install(CKR_IChecklistAuditService.class, audit);
    install(CKR_IChecklistPermissionService.class, allowingPermissions());
  }

  private static CKR_Mocks.MethodRecorder allowingPermissions() {
    return new CKR_Mocks.MethodRecorder()
      .when('canUpdateChecklistInstance', true)
      .when(
        'canUpdateChecklistInstances',
        new Map<Id, Boolean>{ INSTANCE_ID => true }
      );
  }

  private static Set<String> auditEventTypes(CKR_Mocks.MethodRecorder audit) {
    Set<String> eventTypes = new Set<String>();
    for (List<Object> call : allCalls(audit, 'record')) {
      for (CKR_ChecklistAuditEvent__c auditEvent : (List<CKR_ChecklistAuditEvent__c>) call[0]) {
        eventTypes.add(auditEvent.CKR_EventType__c);
      }
    }
    return eventTypes;
  }

  private static List<List<Object>> allCalls(
    CKR_Mocks.MethodRecorder recorder,
    String methodName
  ) {
    List<List<Object>> calls = new List<List<Object>>();
    for (Integer i = 0; i < recorder.callCount(methodName); i++) {
      calls.add(recorder.argumentsAt(methodName, i));
    }
    return calls;
  }

  private static CKR_ChecklistInstance__c viewerInstance() {
    return (CKR_ChecklistInstance__c) CKR_TestRecords.build(
      CKR_ChecklistInstance__c.SObjectType,
      new Map<String, Object>{
        'Id' => INSTANCE_ID,
        'Name' => 'Fallback Name',
        'CKR_ChecklistTemplate__r.Name' => 'Account Launch',
        'CKR_IsComplete__c' => false,
        'CKR_IsOverdue__c' => true,
        'CKR_PercentComplete__c' => 50,
        'CKR_DueDate__c' => Date.today().addDays(-1)
      }
    );
  }

  private static CKR_ChecklistInstanceItem__c viewerItem() {
    return new CKR_ChecklistInstanceItem__c(
      Id = ITEM_ID,
      CKR_ChecklistInstance__c = INSTANCE_ID,
      CKR_Label__c = 'Confirm billing contact',
      CKR_SourceType__c = 'Template',
      CKR_Required__c = true,
      CKR_ExplanationRequired__c = false,
      CKR_ExplanationInputType__c = 'Text',
      CKR_CheckboxValue__c = false,
      CKR_Completed__c = false
    );
  }

  private static CKR_ChecklistInstance__c rollupInstance() {
    return new CKR_ChecklistInstance__c(
      Id = INSTANCE_ID,
      CKR_DueDate__c = Date.today().addDays(1)
    );
  }

  private static CKR_ChecklistInstanceItem__c mutationItem() {
    return (CKR_ChecklistInstanceItem__c) CKR_TestRecords.build(
      CKR_ChecklistInstanceItem__c.SObjectType,
      new Map<String, Object>{
        'Id' => ITEM_ID,
        'CKR_ChecklistInstance__c' => INSTANCE_ID,
        'CKR_ChecklistInstance__r.CKR_ParentRecordId__c' => String.valueOf(
          CKR_TestRecords.fakeId(Account.SObjectType, 1)
        ),
        'CKR_ChecklistInstance__r.CKR_ChecklistTemplateVersion__r.CKR_CompletionAccessMode__c' => 'ReadAccess',
        'CKR_SourceType__c' => 'Template',
        'CKR_Label__c' => 'Confirm billing contact',
        'CKR_Required__c' => true,
        'CKR_ExplanationRequired__c' => false,
        'CKR_ExplanationInputType__c' => 'Text',
        'CKR_CheckboxValue__c' => false,
        'CKR_Completed__c' => false
      }
    );
  }
}
