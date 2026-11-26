@IsTest
private class CKR_ChecklistViewerSelectorTest {
  @IsTest
  static void selectInstancesByParentRecordId_integrationHappyPath_returnsInstancesForTheParent() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.ChecklistInstanceSpec instanceSpec =
        new CKR_TestDataFactory.ChecklistInstanceSpec();
      instanceSpec.accountName = 'Viewer Parent A';
      instanceSpec.templateName = 'Viewer Template A';
      instanceSpec.dueDate = Date.today().addDays(5);
      instanceSpec.requiredItemCount = 1;
      instanceSpec.completedRequiredItemCount = 0;
      instanceSpec.isComplete = false;
      instanceSpec.isOverdue = false;
      instanceSpec.percentComplete = 0;
      CKR_TestDataFactory.ChecklistInstanceFixture matchingFixture =
        CKR_TestDataFactory.createAccountChecklistInstance(instanceSpec);
      CKR_TestDataFactory.ChecklistInstanceSpec otherInstanceSpec =
        new CKR_TestDataFactory.ChecklistInstanceSpec();
      otherInstanceSpec.accountName = 'Viewer Parent B';
      otherInstanceSpec.templateName = 'Viewer Template B';
      otherInstanceSpec.dueDate = Date.today().addDays(3);
      otherInstanceSpec.requiredItemCount = 1;
      otherInstanceSpec.completedRequiredItemCount = 1;
      otherInstanceSpec.isComplete = true;
      otherInstanceSpec.isOverdue = false;
      otherInstanceSpec.percentComplete = 100;
      CKR_TestDataFactory.createAccountChecklistInstance(otherInstanceSpec);

      List<CKR_ChecklistInstance__c> instances =
        new CKR_ChecklistViewerSelector().selectInstancesByParentRecordId(
          String.valueOf(matchingFixture.accountId)
        );

      System.Assert.areEqual(
          1,
          instances.size(),
          'The selector should return only checklist instances for the requested parent record.'
        );
      System.Assert.areEqual(
          matchingFixture.instanceId,
          instances[0].Id,
          'The returned instance should be the one created in the fixture.'
        );
    }
  }

  @IsTest
  static void selectItemsByChecklistInstanceIds_integrationHappyPath_returnsSortedItems() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.ChecklistInstanceSpec instanceSpec =
        new CKR_TestDataFactory.ChecklistInstanceSpec();
      instanceSpec.accountName = 'Viewer Items Parent';
      instanceSpec.templateName = 'Viewer Items Template';
      instanceSpec.requiredItemCount = 0;
      instanceSpec.completedRequiredItemCount = 0;
      instanceSpec.isComplete = false;
      instanceSpec.isOverdue = false;
      instanceSpec.percentComplete = 0;
      CKR_TestDataFactory.ChecklistInstanceFixture fixture =
        CKR_TestDataFactory.createAccountChecklistInstance(instanceSpec);

      insert new List<CKR_ChecklistInstanceItem__c>{
        new CKR_ChecklistInstanceItem__c(
          CKR_ChecklistInstance__c = fixture.instanceId,
          CKR_SourceType__c = 'Template',
          CKR_Label__c = 'Required pending',
          CKR_ExplanationInputType__c = 'Text',
          CKR_Required__c = true,
          CKR_Completed__c = false,
          CKR_SortOrder__c = 2
        ),
        new CKR_ChecklistInstanceItem__c(
          CKR_ChecklistInstance__c = fixture.instanceId,
          CKR_SourceType__c = 'Template',
          CKR_Label__c = 'Optional pending',
          CKR_ExplanationInputType__c = 'Picklist',
          CKR_Required__c = false,
          CKR_Completed__c = false,
          CKR_SortOrder__c = 1
        ),
        new CKR_ChecklistInstanceItem__c(
          CKR_ChecklistInstance__c = fixture.instanceId,
          CKR_SourceType__c = 'AdHoc',
          CKR_Label__c = 'Completed item',
          CKR_ExplanationInputType__c = 'Text',
          CKR_Required__c = false,
          CKR_Completed__c = true,
          CKR_SortOrder__c = 1
        )
      };

      List<CKR_ChecklistInstanceItem__c> items =
        new CKR_ChecklistViewerSelector().selectItemsByChecklistInstanceIds(
          new Set<Id>{ fixture.instanceId }
        );

      System.Assert.areEqual(
          3,
          items.size(),
          'The selector should return all checklist items for the requested instance.'
        );
      System.Assert.areEqual(
          'Required pending',
          items[0].CKR_Label__c,
          'Incomplete required items should sort before other incomplete items.'
        );
      System.Assert.areEqual(
          'Optional pending',
          items[1].CKR_Label__c,
          'Incomplete optional items should follow incomplete required items.'
        );
      System.Assert.areEqual(
          'Completed item',
          items[2].CKR_Label__c,
          'Completed items should sort after incomplete items.'
        );
    }
  }

  @IsTest
  static void selectItemsByChecklistInstanceIds_blankInput_returnsEmptyList() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      List<CKR_ChecklistInstanceItem__c> nullResults =
        new CKR_ChecklistViewerSelector().selectItemsByChecklistInstanceIds(
          null
        );
      List<CKR_ChecklistInstanceItem__c> emptyResults =
        new CKR_ChecklistViewerSelector().selectItemsByChecklistInstanceIds(
          new Set<Id>()
        );

      System.Assert.isTrue(
          nullResults.isEmpty(),
          'A null checklist instance id set should return no items.'
        );
      System.Assert.isTrue(
          emptyResults.isEmpty(),
          'An empty checklist instance id set should return no items.'
        );
    }
  }
}
