// In-memory unit tests exercise logic and stubbed dependencies without database access.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_TestRecordsTest {
  @IsTest
  static void readsBackFormulaAndReadOnlyFields() {
    CKR_ChecklistInstance__c instance =
      (CKR_ChecklistInstance__c) CKR_TestRecords.build(
        CKR_ChecklistInstance__c.SObjectType,
        new Map<String, Object>{
          'Id' => CKR_TestRecords.fakeId(
            CKR_ChecklistInstance__c.SObjectType,
            1
          ),
          'CKR_IsComplete__c' => true,
          'CKR_PercentComplete__c' => 50
        }
      );

    Assert.isTrue(instance.CKR_IsComplete__c);
    Assert.areEqual(50, instance.CKR_PercentComplete__c);
  }

  @IsTest
  static void readsBackTwoLevelRelationships() {
    CKR_ChecklistInstanceItem__c item =
      (CKR_ChecklistInstanceItem__c) CKR_TestRecords.build(
        CKR_ChecklistInstanceItem__c.SObjectType,
        new Map<String, Object>{
          'CKR_ChecklistInstance__r.CKR_ParentRecordId__c' => 'parent',
          'CKR_ChecklistInstance__r.CKR_ChecklistTemplateVersion__r.CKR_CompletionAccessMode__c' => 'EditAccess'
        }
      );

    Assert.areEqual(
      'EditAccess',
      item.CKR_ChecklistInstance__r.CKR_ChecklistTemplateVersion__r.CKR_CompletionAccessMode__c
    );
    Assert.areEqual(
      'parent',
      item.CKR_ChecklistInstance__r.CKR_ParentRecordId__c
    );
  }

  @IsTest
  static void rejectsUnknownFieldsAndRelationships() {
    try {
      CKR_TestRecords.build(
        CKR_ChecklistInstance__c.SObjectType,
        new Map<String, Object>{ 'CKR_NoSuchField__c' => 'x' }
      );
      Assert.fail('Expected an exception for an unknown field');
    } catch (CKR_TestRecords.CKR_TestRecordsException ex) {
      Assert.isTrue(ex.getMessage().contains('CKR_ChecklistInstance__c'));
    }

    try {
      CKR_TestRecords.build(
        CKR_ChecklistInstance__c.SObjectType,
        new Map<String, Object>{ 'CKR_NoSuch__r.Name' => 'x' }
      );
      Assert.fail('Expected an exception for an unknown relationship');
    } catch (CKR_TestRecords.CKR_TestRecordsException ex) {
      Assert.isTrue(ex.getMessage().contains('CKR_NoSuch__r'));
    }
  }

  @IsTest
  static void fakeIdUsesTheTypeKeyPrefix() {
    Id fakeId = CKR_TestRecords.fakeId(Account.SObjectType, 7);

    Assert.isTrue(
      String.valueOf(fakeId)
        .startsWith(
          Account.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
            .getKeyPrefix()
        )
    );
    Assert.areEqual(Account.SObjectType, fakeId.getSObjectType());
  }
}
