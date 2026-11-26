// In-memory unit tests exercise logic and stubbed dependencies without database access.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_TemplateVersionPublishControllerTest {
  @IsTest
  static void delegatesToPublishService() {
    CKR_Mocks.MethodRecorder service = new CKR_Mocks.MethodRecorder();
    CKR_AppFactory.setMock(
      CKR_IChecklistTemplateVersionService.class,
      CKR_Mocks.stub(CKR_IChecklistTemplateVersionService.class, service)
    );
    Id versionId =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 1);
    CKR_TemplateVersionPublishController.publishVersion(versionId);
    System.Assert.areEqual(
        versionId,
        service.lastArguments('publish')[0],
        'Action delegates its record Id to the publish use case.'
      );
    CKR_AppFactory.clearMocks();
  }
  @IsTest
  static void surfacesPublishRejection() {
    CKR_Mocks.MethodRecorder service =
      new CKR_Mocks.MethodRecorder().whenThrow(
        'publish',
        new CKR_DefaultTemplateVersionService.PublishException(
          'Only Draft versions can be published.'
        )
      );
    CKR_AppFactory.setMock(
      CKR_IChecklistTemplateVersionService.class,
      CKR_Mocks.stub(CKR_IChecklistTemplateVersionService.class, service)
    );
    try {
      CKR_TemplateVersionPublishController.publishVersion(null);
      System.Assert.fail('Expected action error.');
    } catch (AuraHandledException failure) {
      System.Assert.areEqual(
          1,
          service.callCount('publish'),
          'Service rejection becomes an action error.'
        );
    }
    CKR_AppFactory.clearMocks();
  }
}
