@IsTest
private class CKR_ChecklistViewerIT {
  @IsTest
  static void updateChecklistItem_rollsUpParentCompletion_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.ChecklistInstanceSpec instanceSpec =
        new CKR_TestDataFactory.ChecklistInstanceSpec();
      instanceSpec.accountName = 'Viewer Update Parent';
      instanceSpec.templateName = 'Viewer Update Template';
      instanceSpec.dueDate = Date.today().addDays(-1);
      instanceSpec.requiredItemCount = 1;
      instanceSpec.completedRequiredItemCount = 0;
      instanceSpec.isComplete = false;
      instanceSpec.isOverdue = true;
      instanceSpec.percentComplete = 0;
      CKR_TestDataFactory.ChecklistInstanceFixture fixture =
        CKR_TestDataFactory.createAccountChecklistInstance(instanceSpec);

      CKR_ChecklistInstanceItem__c itemRecord =
        new CKR_ChecklistInstanceItem__c(
          CKR_ChecklistInstance__c = fixture.instanceId,
          CKR_SourceType__c = 'Template',
          CKR_Label__c = 'Capture sign-off',
          CKR_ExplanationInputType__c = 'Text',
          CKR_Required__c = true,
          CKR_ExplanationRequired__c = true,
          CKR_Completed__c = false,
          CKR_CheckboxValue__c = false,
          CKR_SortOrder__c = 1
        );
      insert itemRecord;

      CKR_ChecklistItemUpdateRequest actionRequest =
        new CKR_ChecklistItemUpdateRequest();
      actionRequest.checklistItemId = itemRecord.Id;
      actionRequest.checkboxValue = true;
      actionRequest.explanation = 'Signed by approver';
      actionRequest.explanationRequired = false;
      CKR_ChecklistViewerController.updateChecklistItem(actionRequest);

      CKR_ChecklistInstanceItem__c refreshedItem = [
        SELECT
          CKR_Completed__c,
          CKR_CheckboxValue__c,
          CKR_Explanation__c,
          CKR_CompletedBy__c,
          CKR_CompletedOn__c
        FROM CKR_ChecklistInstanceItem__c
        WHERE Id = :itemRecord.Id
      ];
      System.Assert.isTrue(
          refreshedItem.CKR_Completed__c,
          'Completing the required checkbox should mark the item complete.'
        );
      System.Assert.isTrue(
          refreshedItem.CKR_CheckboxValue__c,
          'Completing the required checkbox should store the checkbox value.'
        );
      System.Assert.areEqual(
          'Signed by approver',
          refreshedItem.CKR_Explanation__c,
          'The updated explanation should persist on the checklist item.'
        );
      System.Assert.areEqual(
          UserInfo.getUserId(),
          refreshedItem.CKR_CompletedBy__c,
          'Completing an item should stamp the completing user.'
        );
      System.Assert.isNotNull(
          refreshedItem.CKR_CompletedOn__c,
          'Completing an item should stamp the completion timestamp.'
        );

      CKR_ChecklistInstance__c refreshedInstance = [
        SELECT
          CKR_CompletedRequiredItemCount__c,
          CKR_IsComplete__c,
          CKR_IsOverdue__c,
          CKR_PercentComplete__c
        FROM CKR_ChecklistInstance__c
        WHERE Id = :fixture.instanceId
      ];
      System.Assert.areEqual(
          1,
          refreshedInstance.CKR_CompletedRequiredItemCount__c,
          'Rollup should count the completed required item.'
        );
      System.Assert.isTrue(
          refreshedInstance.CKR_IsComplete__c,
          'Rollup should mark the checklist complete when all required items are done.'
        );
      System.Assert.isFalse(
          refreshedInstance.CKR_IsOverdue__c,
          'Completing the final required item should clear the overdue flag.'
        );
      System.Assert.areEqual(
          100,
          refreshedInstance.CKR_PercentComplete__c,
          'Completing the final required item should set percent complete to one hundred.'
        );

      Map<String, CKR_ChecklistAuditEvent__c> auditEventsByType =
        new Map<String, CKR_ChecklistAuditEvent__c>();
      for (CKR_ChecklistAuditEvent__c auditEvent : [
        SELECT CKR_EventType__c, CKR_OldValue__c, CKR_NewValue__c
        FROM CKR_ChecklistAuditEvent__c
        WHERE CKR_ChecklistInstance__c = :fixture.instanceId
      ]) {
        auditEventsByType.put(auditEvent.CKR_EventType__c, auditEvent);
      }
      System.Assert.areEqual(
          3,
          auditEventsByType.size(),
          'Updating the checkbox fixture should produce three audit events.'
        );
      System.Assert.areEqual(
          'false',
          auditEventsByType.get('AnswerChanged').CKR_OldValue__c,
          'AnswerChanged should capture the prior checkbox value.'
        );
      System.Assert.areEqual(
          'true',
          auditEventsByType.get('AnswerChanged').CKR_NewValue__c,
          'AnswerChanged should capture the new checkbox value.'
        );
      System.Assert.isNotNull(
          auditEventsByType.get('ExplanationChanged'),
          'ExplanationChanged should be emitted when the explanation changes.'
        );
      System.Assert.isNotNull(
          auditEventsByType.get('ItemCompleted'),
          'ItemCompleted should be emitted when the item transitions to complete.'
        );
    }
  }

  @IsTest
  static void addAdHocItem_createsOptionalUnlockedItem_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.ChecklistInstanceSpec instanceSpec =
        new CKR_TestDataFactory.ChecklistInstanceSpec();
      instanceSpec.accountName = 'Viewer Ad Hoc Parent';
      instanceSpec.templateName = 'Viewer Ad Hoc Template';
      instanceSpec.requiredItemCount = 0;
      instanceSpec.completedRequiredItemCount = 0;
      instanceSpec.isComplete = true;
      instanceSpec.isOverdue = false;
      instanceSpec.percentComplete = 100;
      CKR_TestDataFactory.ChecklistInstanceFixture fixture =
        CKR_TestDataFactory.createAccountChecklistInstance(instanceSpec);

      CKR_AdHocItemRequest actionRequest2 = new CKR_AdHocItemRequest();
      actionRequest2.checklistInstanceId = fixture.instanceId;
      actionRequest2.label = 'Capture verbal note';
      actionRequest2.explanationInputType = 'Picklist';
      actionRequest2.explanationPicklistValues =
        'Left voicemail;Reached contact';
      actionRequest2.explanationRequired = true;
      CKR_ChecklistViewerController.addAdHocItem(actionRequest2);

      CKR_ChecklistInstanceItem__c itemRecord = [
        SELECT
          CKR_SourceType__c,
          CKR_LockedFromTemplate__c,
          CKR_Label__c,
          CKR_Required__c,
          CKR_ExplanationRequired__c,
          CKR_ExplanationInputType__c,
          CKR_ExplanationPicklistValues__c
        FROM CKR_ChecklistInstanceItem__c
        WHERE CKR_ChecklistInstance__c = :fixture.instanceId
        LIMIT 1
      ];

      System.Assert.areEqual(
          'AdHoc',
          itemRecord.CKR_SourceType__c,
          'Ad hoc creation should mark the source type as AdHoc.'
        );
      System.Assert.isFalse(
          itemRecord.CKR_LockedFromTemplate__c,
          'Ad hoc items should not be locked from template.'
        );
      System.Assert.areEqual(
          'Capture verbal note',
          itemRecord.CKR_Label__c,
          'Ad hoc creation should preserve the entered label.'
        );
      System.Assert.areEqual(
          'Picklist',
          itemRecord.CKR_ExplanationInputType__c,
          'Ad hoc creation should preserve the selected explanation input type.'
        );
      System.Assert.isFalse(
          itemRecord.CKR_Required__c,
          'Ad hoc items should always be optional.'
        );
      System.Assert.isTrue(
          itemRecord.CKR_ExplanationRequired__c,
          'Ad hoc creation should preserve the explanation-required flag.'
        );
      System.Assert.areEqual(
          'Left voicemail;Reached contact',
          itemRecord.CKR_ExplanationPicklistValues__c,
          'Ad hoc creation should persist the explanation picklist value set.'
        );

      CKR_ChecklistAuditEvent__c auditEvent = [
        SELECT CKR_EventType__c, CKR_NewValue__c
        FROM CKR_ChecklistAuditEvent__c
        WHERE CKR_ChecklistInstance__c = :fixture.instanceId
        LIMIT 1
      ];
      System.Assert.areEqual(
          'AdHocItemAdded',
          auditEvent.CKR_EventType__c,
          'Ad hoc creation should write an AdHocItemAdded audit event.'
        );
      System.Assert.areEqual(
          'Capture verbal note',
          auditEvent.CKR_NewValue__c,
          'Ad hoc creation audit should capture the new item label.'
        );
    }
  }
}
