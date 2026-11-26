// In-memory unit tests cover trigger routing through stubbed services and selectors.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_ChecklistTriggerHandlersTest {
  @IsTest
  static void items_updateProtectsSourceTypeAndDeleteProtectsAudit() {
    Id itemId =
      CKR_TestRecords.fakeId(CKR_ChecklistInstanceItem__c.SObjectType, 1);
    CKR_ChecklistInstanceItem__c beforeEdit =
      new CKR_ChecklistInstanceItem__c(
        Id = itemId,
        CKR_SourceType__c = 'Template'
      );
    CKR_ChecklistInstanceItem__c afterEdit =
      new CKR_ChecklistInstanceItem__c(
        Id = itemId,
        CKR_SourceType__c = 'AdHoc'
      );
    Map<Id, CKR_ChecklistInstanceItem__c> oldMap =
      new Map<Id, CKR_ChecklistInstanceItem__c>{ itemId => beforeEdit };
    CKR_Mocks.MethodRecorder retention =
      installRetention('selectAuditedItemIds', itemId);
    try {
      CKR_ChecklistInstanceItemTriggerHandler.handle(
        System.TriggerOperation.BEFORE_UPDATE,
        new List<CKR_ChecklistInstanceItem__c>{ afterEdit },
        oldMap
      );
      System.Assert.isTrue(afterEdit.hasErrors());
      System.Assert.areEqual(0, retention.callCount('selectAuditedItemIds'));

      CKR_ChecklistInstanceItemTriggerHandler.handle(
        System.TriggerOperation.BEFORE_DELETE,
        null,
        oldMap
      );
      System.Assert.isTrue(beforeEdit.hasErrors());
      System.Assert.areEqual(
          new Set<Id>{ itemId },
          (Set<Id>) retention.lastArguments('selectAuditedItemIds')[0]
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void versions_saveRunsLifecycleAndDeleteRunsBothGuards() {
    Id versionId =
      CKR_TestRecords.fakeId(CKR_ChecklistTemplateVersion__c.SObjectType, 1);
    CKR_ChecklistTemplateVersion__c version =
      new CKR_ChecklistTemplateVersion__c(Id = versionId);
    List<CKR_ChecklistTemplateVersion__c> rows =
      new List<CKR_ChecklistTemplateVersion__c>{ version };
    Map<Id, CKR_ChecklistTemplateVersion__c> previous =
      new Map<Id, CKR_ChecklistTemplateVersion__c>(rows);
    CKR_Mocks.MethodRecorder lifecycle = new CKR_Mocks.MethodRecorder();
    CKR_Mocks.MethodRecorder retention =
      installRetention('selectBypassReferencedVersionIds', versionId);
    CKR_AppFactory.setMock(
      CKR_ITemplateVersionLifecycleService.class,
      CKR_Mocks.stub(CKR_ITemplateVersionLifecycleService.class, lifecycle)
    );
    try {
      CKR_TemplateVersionTriggerHandler.handle(
        System.TriggerOperation.BEFORE_INSERT,
        rows,
        null
      );
      CKR_TemplateVersionTriggerHandler.handle(
        System.TriggerOperation.BEFORE_UPDATE,
        rows,
        previous
      );
      System.Assert.areEqual(2, lifecycle.callCount('validateVersions'));
      System.Assert.isNull(lifecycle.argumentsAt('validateVersions', 0)[1]);
      System.Assert.areEqual(
          previous,
          lifecycle.argumentsAt('validateVersions', 1)[1]
        );
      System.Assert.areEqual(
          0,
          retention.callCount('selectBypassReferencedVersionIds')
        );

      CKR_TemplateVersionTriggerHandler.handle(
        System.TriggerOperation.BEFORE_DELETE,
        null,
        previous
      );
      System.Assert.areEqual(1, lifecycle.callCount('validateDeletes'));
      System.Assert.areEqual(
          rows,
          lifecycle.lastArguments('validateDeletes')[0]
        );
      System.Assert.isTrue(version.hasErrors());
      System.Assert.areEqual(
          1,
          retention.callCount('selectBypassReferencedVersionIds')
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  private static CKR_Mocks.MethodRecorder installRetention(
    String methodName,
    Id protectedId
  ) {
    CKR_Mocks.MethodRecorder retention =
      new CKR_Mocks.MethodRecorder().when(
        methodName,
        new Set<Id>{ protectedId }
      );
    CKR_AppFactory.setMock(
      CKR_IAuditRetentionSelector.class,
      CKR_Mocks.stub(CKR_IAuditRetentionSelector.class, retention)
    );
    return retention;
  }
}
