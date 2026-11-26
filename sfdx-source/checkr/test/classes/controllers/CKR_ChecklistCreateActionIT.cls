@IsTest
private class CKR_ChecklistCreateActionIT {
  @IsTest
  static void createChecklist_createsInstanceAndTemplateItems_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      Account account = new Account(Name = 'Acme');
      insert account;

      CKR_TestDataFactory.TemplateFixture templateFixture =
        CKR_TestDataFactory.createPublishedAccountTemplate('Account Readiness');

      CKR_ChecklistInstanceCreateRequest actionRequest =
        new CKR_ChecklistInstanceCreateRequest();
      actionRequest.templateId = templateFixture.templateId;
      actionRequest.parentRecordId = account.Id;
      actionRequest.parentObjectApiName = 'Account';
      actionRequest.dueDate = Date.today().addDays(7);
      CKR_ChecklistInstanceCreateResult result =
        CKR_ChecklistCreateActionController.createChecklistAction(
          actionRequest
        );

      System.Assert.isTrue(
          result.success,
          'Happy-path integration create should succeed.'
        );
      System.Assert.isNotNull(
          result.checklistInstanceId,
          'Successful checklist creation should return the new instance id.'
        );

      CKR_ChecklistInstance__c instanceRecord = [
        SELECT
          CKR_ChecklistTemplate__c,
          CKR_ChecklistTemplateVersion__c,
          CKR_ParentRecordId__c,
          CKR_ParentObjectApiName__c,
          CKR_RequiredItemCount__c,
          CKR_CompletedRequiredItemCount__c,
          CKR_IsComplete__c,
          CKR_PercentComplete__c
        FROM CKR_ChecklistInstance__c
        WHERE Id = :result.checklistInstanceId
      ];

      System.Assert.areEqual(
          templateFixture.templateId,
          instanceRecord.CKR_ChecklistTemplate__c,
          'Instance should point to the source template.'
        );
      System.Assert.areEqual(
          templateFixture.versionId,
          instanceRecord.CKR_ChecklistTemplateVersion__c,
          'Instance should point to the published template version used to create it.'
        );
      System.Assert.areEqual(
          String.valueOf(account.Id),
          instanceRecord.CKR_ParentRecordId__c,
          'Instance should snapshot the parent record id.'
        );
      System.Assert.areEqual(
          'Account',
          instanceRecord.CKR_ParentObjectApiName__c,
          'Instance should snapshot the parent object API name.'
        );
      System.Assert.areEqual(
          1,
          instanceRecord.CKR_RequiredItemCount__c,
          'Required item count should roll up from the template items.'
        );
      System.Assert.areEqual(
          0,
          instanceRecord.CKR_CompletedRequiredItemCount__c,
          'Newly created instances should start with zero completed required items.'
        );
      System.Assert.isFalse(
          instanceRecord.CKR_IsComplete__c,
          'A checklist with an incomplete required item should not start complete.'
        );
      System.Assert.areEqual(
          0,
          instanceRecord.CKR_PercentComplete__c,
          'Newly created instances with incomplete required items should start at zero percent complete.'
        );

      List<CKR_ChecklistInstanceItem__c> itemRecords = [
        SELECT
          CKR_Label__c,
          CKR_ExplanationInputType__c,
          CKR_Required__c,
          CKR_SourceType__c,
          CKR_LockedFromTemplate__c,
          CKR_Completed__c
        FROM CKR_ChecklistInstanceItem__c
        WHERE CKR_ChecklistInstance__c = :result.checklistInstanceId
        ORDER BY CKR_SortOrder__c ASC
      ];

      System.Assert.areEqual(
          2,
          itemRecords.size(),
          'Instance creation should clone both active template items.'
        );
      System.Assert.areEqual(
          'Confirm billing contact',
          itemRecords[0].CKR_Label__c,
          'The first cloned item should preserve the source template label.'
        );
      System.Assert.isTrue(
          itemRecords[0].CKR_Required__c,
          'Required template items should remain required on the instance.'
        );
      System.Assert.areEqual(
          'Template',
          itemRecords[0].CKR_SourceType__c,
          'Cloned items should be marked as template-derived.'
        );
      System.Assert.isTrue(
          itemRecords[0].CKR_LockedFromTemplate__c,
          'Template-derived items should be locked from template.'
        );
      System.Assert.isFalse(
          itemRecords[0].CKR_Completed__c,
          'Newly cloned items should start incomplete.'
        );
      System.Assert.areEqual(
          'Picklist',
          itemRecords[1].CKR_ExplanationInputType__c,
          'The second cloned item should preserve its explanation input type.'
        );
    }
  }
}
