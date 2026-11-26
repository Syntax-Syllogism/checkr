@IsTest
private class CKR_InsertGatingIT {
  @IsTest
  static void insertingMatchingRecordIsNotGatedByDesign() {
    CKR_TestDataFactory.TemplateFixture fixture =
      CKR_TestDataFactory.createDraftAccountTemplate('Insert D3');
    CKR_TestDataFactory.addAccountTemplateItems(fixture.versionId);
    insert new CKR_ChecklistGateRule__c(
      CKR_ChecklistTemplateVersion__c = fixture.versionId,
      CKR_Active__c = true,
      CKR_ProtectedActionType__c = 'SpecificFieldValueChange',
      CKR_TargetFieldApiName__c = 'Rating',
      CKR_TargetValue__c = 'Hot'
    );
    CKR_TestDataFactory.publishTemplateVersion(
      fixture.templateId,
      fixture.versionId
    );
    // D3: Trigger.newMap is null in before insert; inserts remain ungated.
    Account candidate = new Account(Name = 'D3 ungated insert', Rating = 'Hot');
    insert candidate;
    System.Assert.isNotNull(
        candidate.Id,
        'A matching Account insert succeeds through the reference trigger.'
      );
  }
}
