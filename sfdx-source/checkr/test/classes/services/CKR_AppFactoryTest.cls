// In-memory unit tests exercise logic and stubbed dependencies without database access.
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest
private class CKR_AppFactoryTest {
  private static final List<Type> PRODUCTION_PORTS =
    new List<Type>{
      CKR_ISupportedObjectSelector.class,
      CKR_IChecklistGateSelector.class,
      CKR_IChecklistCreateContextSelector.class,
      CKR_IChecklistViewerSelector.class,
      CKR_IParentAccessGateway.class,
      CKR_IDmlGateway.class,
      CKR_ISystemDmlGateway.class,
      CKR_IChecklistInstanceSelector.class,
      CKR_IChecklistMutationSelector.class,
      CKR_IChecklistGateService.class,
      CKR_IGateBypass.class,
      CKR_IChecklistInstanceService.class,
      CKR_IChecklistPermissionService.class,
      CKR_IChecklistAuditService.class
    };

  @IsTest
  static void resolvesEveryProductionPort() {
    for (Type port : PRODUCTION_PORTS) {
      Object resolved = CKR_AppFactory.getInstance(port);
      System.Assert.isNotNull(resolved, 'The factory should resolve ' + port);
    }
  }

  @IsTest
  static void resolvesExpectedDefaultImplementations() {
    System.Assert.isInstanceOfType(
        CKR_AppFactory.getInstance(CKR_IDmlGateway.class),
        CKR_DefaultDmlGateway.class,
        'The user-facing DML port should resolve to the user-mode gateway.'
      );
    System.Assert.isInstanceOfType(
        CKR_AppFactory.getInstance(CKR_ISystemDmlGateway.class),
        CKR_SystemModeDmlGateway.class,
        'The system DML port should resolve to the system-mode gateway.'
      );
  }

  @IsTest
  static void rejectsUnregisteredPorts() {
    try {
      CKR_AppFactory.getInstance(String.class);
      System.Assert.fail('Unregistered types should not resolve.');
    } catch (CKR_AppFactoryException ex) {
      System.Assert.isTrue(
          ex.getMessage().contains('No application implementation registered'),
          'The exception should explain that nothing is registered.'
        );
    }
  }

  @IsTest
  static void mocksOverrideDefaultsUntilCleared() {
    CKR_Mocks.MethodRecorder recorder = new CKR_Mocks.MethodRecorder();
    Object stub = CKR_Mocks.stub(CKR_IDmlGateway.class, recorder);
    CKR_AppFactory.setMock(CKR_IDmlGateway.class, stub);

    System.Assert.isTrue(
        stub === CKR_AppFactory.getInstance(CKR_IDmlGateway.class),
        'A registered mock should win over the default implementation.'
      );

    CKR_AppFactory.clearMocks();

    System.Assert.isInstanceOfType(
        CKR_AppFactory.getInstance(CKR_IDmlGateway.class),
        CKR_DefaultDmlGateway.class,
        'Clearing mocks should restore the default implementation.'
      );
  }
}
