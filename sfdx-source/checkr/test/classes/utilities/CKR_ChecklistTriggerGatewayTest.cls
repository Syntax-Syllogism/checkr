// In-memory unit tests exercise logic and stubbed dependencies without database access.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_ChecklistTriggerGatewayTest {
  @IsTest
  static void insertIsNotGated() {
    CKR_Mocks.MethodRecorder gate =
      installGate(new List<CKR_ChecklistGateResult>());
    // D3: before insert has no newMap or record Id and deliberately skips gating.
    CKR_ChecklistTriggerGateway.handleBefore('Account', null, null);
    System.Assert.areEqual(
        0,
        gate.callCount('evaluate'),
        'D3 keeps inserts ungated.'
      );
    CKR_AppFactory.clearMocks();
  }

  @IsTest
  static void handleBefore_appliesBlockingErrors() {
    Id recordId = CKR_TestRecords.fakeId(Account.SObjectType, 1);
    installGate(
      new List<CKR_ChecklistGateResult>{
        CKR_ChecklistGateResult.blocked(recordId, 'Blocked by test gate.')
      }
    );

    try {
      Account record = new Account(Name = 'Blocked');
      Map<Id, SObject> newMap = new Map<Id, SObject>{ recordId => record };

      CKR_ChecklistTriggerGateway.handleBefore('Account', null, newMap);

      System.Assert.areEqual(
          1,
          record.getErrors().size(),
          'Blocked gate results should add one error to the target record.'
        );
      System.Assert.areEqual(
          'Blocked by test gate.',
          record.getErrors()[0].getMessage(),
          'Trigger gateway should surface the gate-service error message on the record.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void handleBefore_isNullSafe() {
    CKR_Mocks.MethodRecorder gate =
      installGate(new List<CKR_ChecklistGateResult>());

    try {
      CKR_ChecklistTriggerGateway.handleBefore(null, null, null);
      CKR_ChecklistTriggerGateway.handleBefore(
        'Account',
        null,
        new Map<Id, SObject>()
      );

      System.Assert.areEqual(
          0,
          gate.callCount('evaluate'),
          'Empty trigger contexts should not reach the gate service.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  @IsTest
  static void handleBefore_usesDefaultErrorMessageWhenBlank() {
    Id recordId = CKR_TestRecords.fakeId(Account.SObjectType, 2);
    CKR_ChecklistGateResult blank = new CKR_ChecklistGateResult();
    blank.recordId = recordId;
    blank.allowed = false;
    blank.errorMessage = null;
    installGate(new List<CKR_ChecklistGateResult>{ blank });

    try {
      Account record = new Account(Name = 'Blocked');
      Map<Id, SObject> newMap = new Map<Id, SObject>{ recordId => record };

      CKR_ChecklistTriggerGateway.handleBefore('Account', null, newMap);

      System.Assert.areEqual(
          1,
          record.getErrors().size(),
          'Blank gate messages should still block the record once.'
        );
      System.Assert.areEqual(
          'Checklist gate requirements are not satisfied.',
          record.getErrors()[0].getMessage(),
          'Trigger gateway should supply the default message when the gate service omits one.'
        );
    } finally {
      CKR_AppFactory.clearMocks();
    }
  }

  private static CKR_Mocks.MethodRecorder installGate(
    List<CKR_ChecklistGateResult> results
  ) {
    CKR_Mocks.MethodRecorder gate =
      new CKR_Mocks.MethodRecorder().when('evaluate', results);
    CKR_AppFactory.setMock(
      CKR_IChecklistGateService.class,
      CKR_Mocks.stub(CKR_IChecklistGateService.class, gate)
    );
    return gate;
  }
}
