@IsTest
private class CKR_ChecklistCreateContextSelectorTest {
  @IsTest
  static void selectAvailableTemplatesForObject_integrationHappyPath_returnsMatchingPublishedTemplates() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.TemplateFixture accountFixture =
        CKR_TestDataFactory.createPublishedAccountTemplate(
          'Account Create Context'
        );

      CKR_ChecklistTemplate__c opportunityTemplate =
        new CKR_ChecklistTemplate__c(
          Name = 'Opportunity Create Context',
          CKR_DeveloperName__c = 'Opportunity_Create_Context',
          CKR_SupportedObjectDeveloperName__c = 'Opportunity',
          CKR_TargetObjectApiName__c = 'Opportunity',
          CKR_Active__c = true
        );
      insert opportunityTemplate;

      CKR_ChecklistTemplateVersion__c opportunityVersion =
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = opportunityTemplate.Id,
          CKR_Status__c = 'Draft',
          CKR_VersionNumber__c = 1,
          CKR_CompletionAccessMode__c = 'ReadAccess'
        );
      insert opportunityVersion;
      CKR_TestDataFactory.addAccountTemplateItems(opportunityVersion.Id);
      CKR_TestDataFactory.publishTemplateVersion(
        opportunityTemplate.Id,
        opportunityVersion.Id
      );

      List<CKR_ChecklistTemplate__c> templates =
        new CKR_ChecklistCreateContextSelector().selectAvailableTemplatesForObject(
          'Account'
        );

      System.Assert.areEqual(
          1,
          templates.size(),
          'The selector should return only the published Account template.'
        );
      System.Assert.areEqual(
          accountFixture.templateId,
          templates[0].Id,
          'The returned template should be the Account template fixture.'
        );
      System.Assert.areEqual(
          accountFixture.versionId,
          templates[0].CKR_CurrentPublishedVersion__c,
          'The returned template should expose its current published version.'
        );
      System.Assert.areEqual(
          'Account Create Context',
          templates[0].Name,
          'The returned template should preserve the source template name.'
        );
      System.Assert.areEqual(
          1,
          templates[0].CKR_CurrentPublishedVersion__r.CKR_VersionNumber__c,
          'The returned template should expose the published version number.'
        );
    }
  }

  @IsTest
  static void selectAvailableTemplatesForObject_blankObjectApiName_returnsEmptyList() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_TestDataFactory.createPublishedAccountTemplate('Unused Template');

      List<CKR_ChecklistTemplate__c> nullResults =
        new CKR_ChecklistCreateContextSelector().selectAvailableTemplatesForObject(
          null
        );
      List<CKR_ChecklistTemplate__c> blankResults =
        new CKR_ChecklistCreateContextSelector().selectAvailableTemplatesForObject(
          '   '
        );

      System.Assert.isTrue(
          nullResults.isEmpty(),
          'A blank object API name should return no templates.'
        );
      System.Assert.isTrue(
          blankResults.isEmpty(),
          'Whitespace-only object API names should also return no templates.'
        );
    }
  }
}
