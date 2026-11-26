// In-memory unit tests exercise logic and stubbed dependencies without database access.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_ChecklistPermissionServiceTest {
  @IsTest
  static void canUpdateChecklistInstances_allowsReadAccessForReadableParent() {
    Id parentId = CKR_TestRecords.fakeId(Account.SObjectType, 11);
    Id instanceId =
      CKR_TestRecords.fakeId(CKR_ChecklistInstance__c.SObjectType, 11);
    installGateway(parentId, new CKR_ParentAccess(CKR_ParentAccessLevel.READ));

    try {
      CKR_ChecklistInstance__c instanceRecord =
        buildInstance(
          instanceId,
          parentId,
          new Map<String, Object>{
            'CKR_CompletionAccessMode__c' => 'ReadAccess'
          }
        );

      Map<Id, Boolean> results =
        new CKR_DefaultChecklistPermissionService().canUpdateChecklistInstances(
          new List<CKR_ChecklistInstance__c>{ instanceRecord }
        );

      System.Assert.isTrue(
          results.get(instanceId),
          'ReadAccess templates should be editable when the parent record is readable.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void canUpdateChecklistInstances_deniesMissingCustomPermission() {
    Id parentId = CKR_TestRecords.fakeId(Account.SObjectType, 12);
    Id instanceId =
      CKR_TestRecords.fakeId(CKR_ChecklistInstance__c.SObjectType, 12);
    CKR_Mocks.MethodRecorder gateway =
      installGateway(
        parentId,
        new CKR_ParentAccess(CKR_ParentAccessLevel.EDIT)
      );

    try {
      CKR_ChecklistInstance__c instanceRecord =
        buildInstance(
          instanceId,
          parentId,
          new Map<String, Object>{
            'CKR_CompletionAccessMode__c' => 'CustomPermission',
            'CKR_CustomPermissionDeveloperName__c' => 'CKR_Missing_Custom_Permission'
          }
        );

      System.Assert.isFalse(
          new CKR_DefaultChecklistPermissionService().canUpdateChecklistInstance(
            instanceRecord
          ),
          'CustomPermission mode should deny updates when the named custom permission is missing.'
        );
      System.Assert.areEqual(
          'CKR_Missing_Custom_Permission',
          gateway.lastArguments('hasCustomPermission')[0],
          'The named custom permission should be checked.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void canUpdateChecklistInstances_allowsGrantedCustomPermission() {
    Id parentId = CKR_TestRecords.fakeId(Account.SObjectType, 14);
    installGateway(parentId, new CKR_ParentAccess(CKR_ParentAccessLevel.READ))
      .when('hasCustomPermission', true);

    try {
      System.Assert.isTrue(
          new CKR_DefaultChecklistPermissionService().canUpdateChecklistInstance(
            buildInstance(
              CKR_TestRecords.fakeId(CKR_ChecklistInstance__c.SObjectType, 14),
              parentId,
              new Map<String, Object>{
                'CKR_CompletionAccessMode__c' => 'CustomPermission',
                'CKR_CustomPermissionDeveloperName__c' => 'CKR_Granted'
              }
            )
          ),
          'CustomPermission mode should allow updates when the permission is granted.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void canUpdateChecklistInstances_requiresEditAccessForEditMode() {
    Id parentId = CKR_TestRecords.fakeId(Account.SObjectType, 13);
    Id instanceId =
      CKR_TestRecords.fakeId(CKR_ChecklistInstance__c.SObjectType, 13);
    installGateway(parentId, new CKR_ParentAccess(CKR_ParentAccessLevel.READ));

    try {
      CKR_ChecklistInstance__c instanceRecord =
        buildInstance(
          instanceId,
          parentId,
          new Map<String, Object>{
            'CKR_CompletionAccessMode__c' => 'EditAccess'
          }
        );

      System.Assert.isFalse(
          new CKR_DefaultChecklistPermissionService().canUpdateChecklistInstance(
            instanceRecord
          ),
          'EditAccess mode should deny updates when the parent record is not editable.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void parentAccessLevel_preservesReadAndEditHierarchy() {
    CKR_ParentAccess noAccess =
      new CKR_ParentAccess(CKR_ParentAccessLevel.NONE);
    System.Assert.isFalse(noAccess.hasReadAccess);
    System.Assert.isFalse(noAccess.hasEditAccess);
    CKR_ParentAccess readAccess =
      new CKR_ParentAccess(CKR_ParentAccessLevel.READ);
    System.Assert.isTrue(readAccess.hasReadAccess);
    System.Assert.isFalse(readAccess.hasEditAccess);
    CKR_ParentAccess editAccess =
      new CKR_ParentAccess(CKR_ParentAccessLevel.EDIT);
    System.Assert.isTrue(editAccess.hasReadAccess);
    System.Assert.isTrue(editAccess.hasEditAccess);
  }

  private static CKR_Mocks.MethodRecorder installGateway(
    Id parentId,
    CKR_ParentAccess access
  ) {
    CKR_Mocks.MethodRecorder gateway =
      new CKR_Mocks.MethodRecorder()
        .when(
          'loadParentAccess',
          new Map<Id, CKR_ParentAccess>{ parentId => access }
        )
        .when('hasCustomPermission', false);
    CKR_AppFactory.setMock(
      CKR_IParentAccessGateway.class,
      CKR_Mocks.stub(CKR_IParentAccessGateway.class, gateway)
    );
    return gateway;
  }

  private static CKR_ChecklistInstance__c buildInstance(
    Id instanceId,
    Id parentId,
    Map<String, Object> versionFields
  ) {
    Map<String, Object> fields =
      new Map<String, Object>{
        'Id' => instanceId,
        'CKR_ParentRecordId__c' => String.valueOf(parentId)
      };
    for (String field : versionFields.keySet()) {
      fields.put(
        'CKR_ChecklistTemplateVersion__r.' + field,
        versionFields.get(field)
      );
    }
    return (CKR_ChecklistInstance__c) CKR_TestRecords.build(
      CKR_ChecklistInstance__c.SObjectType,
      fields
    );
  }
}
