@IsTest
private class CKR_DefaultDmlGatewayTest {
  @IsTest
  static void nullAndEmptyInputs_areIgnoredWithoutThrowing() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      // runAs counts against the DML statement limit in a real org, so
      // measure the gateway's own DML as a delta from here.
      Integer dmlBefore = Limits.getDmlStatements();
      CKR_IDmlGateway gateway = new CKR_DefaultDmlGateway();

      System.Assert.areEqual(
          0,
          gateway.doInsert(null, CKR_DmlMode.ALL_OR_NONE).size(),
          'Null inserts should return no results.'
        );
      System.Assert.areEqual(
          0,
          gateway.doInsert(new List<SObject>(), CKR_DmlMode.ALL_OR_NONE).size(),
          'Empty inserts should return no results.'
        );
      System.Assert.areEqual(
          0,
          gateway.doUpdate(null, CKR_DmlMode.ALL_OR_NONE).size(),
          'Null updates should return no results.'
        );
      System.Assert.areEqual(
          0,
          gateway.doUpdate(new List<SObject>(), CKR_DmlMode.ALL_OR_NONE).size(),
          'Empty updates should return no results.'
        );
      System.Assert.areEqual(
          0,
          gateway.doDelete(null, CKR_DmlMode.ALL_OR_NONE).size(),
          'Null deletes should return no results.'
        );
      System.Assert.areEqual(
          0,
          gateway.doDelete(new List<SObject>(), CKR_DmlMode.ALL_OR_NONE).size(),
          'Empty deletes should return no results.'
        );

      System.Assert.areEqual(
          dmlBefore,
          Limits.getDmlStatements(),
          'Null and empty inputs should be ignored without consuming DML statements.'
        );
    }
  }

  @IsTest
  static void basicDmlPaths_integrationHappyPath_insertUpdateAndDeleteRecords() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_IDmlGateway gateway = new CKR_DefaultDmlGateway();

      Account firstAccount = new Account(Name = 'Gateway One');
      Account secondAccount = new Account(Name = 'Gateway Two');
      List<SObject> records = new List<SObject>{ firstAccount, secondAccount };

      List<Database.SaveResult> inserted =
        gateway.doInsert(records, CKR_DmlMode.ALL_OR_NONE);
      System.Assert.areEqual(
          2,
          inserted.size(),
          'Each record should get a save result.'
        );

      System.Assert.isNotNull(
          firstAccount.Id,
          'Inserted records should receive an id.'
        );
      System.Assert.isNotNull(
          secondAccount.Id,
          'Inserted records should receive an id.'
        );

      firstAccount.Name = 'Gateway One Updated';
      secondAccount.Name = 'Gateway Two Updated';
      gateway.doUpdate(records, CKR_DmlMode.ALL_OR_NONE);

      Set<Id> accountIds = new Set<Id>{ firstAccount.Id, secondAccount.Id };
      List<Account> updatedAccounts = [
        SELECT Id, Name
        FROM Account
        WHERE Id IN :accountIds
        ORDER BY Name ASC
      ];
      System.Assert.areEqual(
          2,
          updatedAccounts.size(),
          'Updated records should still be queryable after the gateway update path.'
        );
      System.Assert.areEqual(
          'Gateway One Updated',
          updatedAccounts[0].Name,
          'The gateway should persist the first updated record.'
        );
      System.Assert.areEqual(
          'Gateway Two Updated',
          updatedAccounts[1].Name,
          'The gateway should persist the second updated record.'
        );

      gateway.doDelete(records, CKR_DmlMode.ALL_OR_NONE);

      Set<Id> deletedAccountIds =
        new Set<Id>{ firstAccount.Id, secondAccount.Id };
      List<Account> deletedAccounts = [
        SELECT Id, IsDeleted, Name
        FROM Account
        WHERE Id IN :deletedAccountIds
        ORDER BY Name ASC
        ALL ROWS
      ];
      System.Assert.areEqual(
          2,
          deletedAccounts.size(),
          'Deleted records should remain visible in an ALL ROWS query for verification.'
        );
      System.Assert.isTrue(
          deletedAccounts[0].IsDeleted,
          'The gateway should delete the first record.'
        );
      System.Assert.isTrue(
          deletedAccounts[1].IsDeleted,
          'The gateway should delete the second record.'
        );
    }
  }

  @IsTest
  static void doInsert_partialSuccessReportsFailuresWhenNotAllOrNone() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_IDmlGateway gateway = new CKR_DefaultDmlGateway();
      List<SObject> records =
        new List<SObject>{ new Account(Name = 'Valid'), new Account() };

      List<Database.SaveResult> results =
        gateway.doInsert(records, CKR_DmlMode.PARTIAL);

      System.Assert.isTrue(
          results[0].isSuccess(),
          'The valid record should save when allOrNone is false.'
        );
      System.Assert.isFalse(
          results[1].isSuccess(),
          'The record missing its required Name should report a failure.'
        );
    }
  }

  @IsTest
  static void doInsert_allOrNoneThrowsOnFailure() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_IDmlGateway gateway = new CKR_DefaultDmlGateway();
      try {
        gateway.doInsert(
          new List<SObject>{ new Account() },
          CKR_DmlMode.ALL_OR_NONE
        );
        System.Assert.fail('allOrNone inserts should throw on failure.');
      } catch (DmlException ex) {
        System.Assert.isTrue(
            ex.getMessage().contains('REQUIRED_FIELD_MISSING'),
            'The failure should identify the missing required field.'
          );
      }
    }
  }

  @IsTest
  static void systemModeGateway_insertsRecords() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_ISystemDmlGateway gateway = new CKR_SystemModeDmlGateway();
      Account account = new Account(Name = 'System Gateway');

      gateway.doInsert(new List<SObject>{ account }, CKR_DmlMode.ALL_OR_NONE);

      System.Assert.isNotNull(
          account.Id,
          'The system-mode gateway should insert records.'
        );
    }
  }
  @IsTest
  static void systemModeGateway_partialReturnsPerRowResults() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      List<Database.SaveResult> results =
        new CKR_SystemModeDmlGateway().doInsert(
          new List<SObject>{
            new Account(Name = 'Partial success'),
            new Account()
          },
          CKR_DmlMode.PARTIAL
        );
      System.Assert.isTrue(results[0].isSuccess());
      System.Assert.isFalse(results[1].isSuccess());
      System.Assert.areEqual(
          StatusCode.REQUIRED_FIELD_MISSING,
          results[1].getErrors()[0].getStatusCode()
        );
    }
  }

  @IsTest
  static void bothGateways_nullModeRollsBackTheBatch() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      assertAtomicInsert(new CKR_DefaultDmlGateway(), null);
      assertAtomicInsert(new CKR_SystemModeDmlGateway(), null);
      assertAtomicInsert(
        new CKR_SystemModeDmlGateway(),
        CKR_DmlMode.ALL_OR_NONE
      );
      System.Assert.areEqual(
          0,
          [SELECT count() FROM Account WHERE Name = 'Atomic batch']
        );
    }
  }

  private static void assertAtomicInsert(
    CKR_IDmlGateway gateway,
    CKR_DmlMode mode
  ) {
    try {
      gateway.doInsert(
        new List<SObject>{ new Account(Name = 'Atomic batch'), new Account() },
        mode
      );
      System.Assert.fail('An atomic insert must fail when any row is invalid.');
    } catch (DmlException ex) {
      System.Assert.areEqual(
          'REQUIRED_FIELD_MISSING',
          String.valueOf(ex.getDmlStatusCode(0))
        );
    }
  }
}
