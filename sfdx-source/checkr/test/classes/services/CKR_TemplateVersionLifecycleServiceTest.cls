// In-memory unit tests exercise logic and stubbed dependencies without database access.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_TemplateVersionLifecycleServiceTest {
  @IsTest
  static void bulkManualPublicationsAreRejected() {
    List<CKR_ChecklistTemplateVersion__c> versions =
      new List<CKR_ChecklistTemplateVersion__c>();
    for (Integer index = 1; index <= 200; index++) {
      versions.add(
        new CKR_ChecklistTemplateVersion__c(CKR_Status__c = 'Published')
      );
    }
    new CKR_TemplateVersionLifecycleService().validateVersions(versions, null);
    for (CKR_ChecklistTemplateVersion__c version : versions) {
      System.Assert.isTrue(
          version.hasErrors(),
          'Every direct publication in a bulk insert is rejected.'
        );
    }
  }
  @IsTest
  static void historicalCannotBeReopenedOrEdited() {
    Id versionId =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 1);
    CKR_ChecklistTemplateVersion__c previous =
      new CKR_ChecklistTemplateVersion__c(
        Id = versionId,
        CKR_Status__c = 'Historical'
      );
    CKR_ChecklistTemplateVersion__c attempted =
      new CKR_ChecklistTemplateVersion__c(
        Id = versionId,
        CKR_Status__c = 'Draft'
      );
    new CKR_TemplateVersionLifecycleService().validateVersions(
      new List<CKR_ChecklistTemplateVersion__c>{ attempted },
      new Map<Id, CKR_ChecklistTemplateVersion__c>{ versionId => previous }
    );
    System.Assert.isTrue(
        attempted.hasErrors(),
        'Historical status cannot return to Draft.'
      );
  }
  @IsTest
  static void draftEditsRemainAllowed() {
    Id versionId =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 1);
    CKR_ChecklistTemplateVersion__c draft =
      new CKR_ChecklistTemplateVersion__c(
        Id = versionId,
        CKR_Status__c = 'Draft'
      );
    new CKR_TemplateVersionLifecycleService().validateVersions(
      new List<CKR_ChecklistTemplateVersion__c>{ draft },
      new Map<Id, CKR_ChecklistTemplateVersion__c>{ versionId => draft }
    );
    System.Assert.isFalse(
        draft.hasErrors(),
        'Draft configuration remains editable.'
      );
  }
}
