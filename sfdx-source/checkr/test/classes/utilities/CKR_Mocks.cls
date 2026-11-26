@IsTest
public class CKR_Mocks {
  /**
   * Returns the stub.
   * @param interfaceType Value used by this operation.
   * @param provider Value used by this operation.
   * @return Value produced by this operation.
   */
  public static Object stub(Type interfaceType, System.StubProvider provider) {
    return Test.createStub(interfaceType, provider);
  }

  /**
   * Provides method recorder behavior for the checkr application.
   */
  public class MethodRecorder implements System.StubProvider {
    private Map<String, Object> responses = new Map<String, Object>();
    private Map<String, Integer> failureCallNumbers =
      new Map<String, Integer>();
    private Boolean forwardUpdates = false;
    private Set<String> idAssigningMethods = new Set<String>();
    private Integer idSequence = 0;
    private Map<String, Exception> failures = new Map<String, Exception>();
    private Map<String, List<Object>> responseSequences =
      new Map<String, List<Object>>();
    private Map<String, List<List<Object>>> invocations =
      new Map<String, List<List<Object>>>();

    /**
     * Returns the when.
     * @param methodName Value used by this operation.
     * @param response Value used by this operation.
     * @return Value produced by this operation.
     */
    public MethodRecorder when(String methodName, Object response) {
      responses.put(methodName, response);
      return this;
    }

    /**
     * Makes every call to the method throw the supplied exception.
     * @param methodName Value used by this operation.
     * @param failure Exception thrown when the method is called.
     * @return Value produced by this operation.
     */
    public MethodRecorder whenThrow(String methodName, Exception failure) {
      failures.put(methodName, failure);
      return this;
    }

    /**
     * Gives records without an Id a fake Id when the method is called, as a
     * real insert would, so callers can read Ids back.
     * @param methodName Method whose first argument is a List<SObject>.
     * @return Value produced by this operation.
     */
    public MethodRecorder assignsIds(String methodName) {
      idAssigningMethods.add(methodName);
      return this;
    }

    /**
     * Fails a specific invocation, permitting integration tests of rollback after earlier DML.
     * @param methodName the stubbed operation to fail
     * @param callNumber one-based index of the invocation that should fail
     * @param failure exception to throw on that invocation
     * @return this recorder for continued configuration
     */
    public MethodRecorder whenThrowOnCall(
      String methodName,
      Integer callNumber,
      Exception failure
    ) {
      failures.put(methodName, failure);
      failureCallNumbers.put(methodName, callNumber);
      return this;
    }

    /**
     * Executes real user-mode updates; use only in explicitly named integration tests.
     * @return this recorder for continued configuration
     */
    public MethodRecorder performsRealUpdates() {
      forwardUpdates = true;
      return this;
    }

    // Returns each response in order on successive calls, then repeats the
    // last one. Lets a paging fixture end instead of returning the same page
    // forever.
    /**
     * Returns the when sequence.
     * @param methodName Value used by this operation.
     * @param orderedResponses Value used by this operation.
     * @return Value produced by this operation.
     */
    public MethodRecorder whenSequence(
      String methodName,
      List<Object> orderedResponses
    ) {
      responseSequences.put(methodName, orderedResponses);
      return this;
    }

    /**
     * Returns the handle method call.
     * @param stubbedObject Value used by this operation.
     * @param stubbedMethodName Value used by this operation.
     * @param returnType Value used by this operation.
     * @param listOfParameterTypes Value used by this operation.
     * @param listOfParameterNames Value used by this operation.
     * @param listOfArgs Value used by this operation.
     * @return Value produced by this operation.
     */
    // Signature fixed by System.StubProvider.
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public Object handleMethodCall(
      Object stubbedObject,
      String stubbedMethodName,
      Type returnType,
      List<Type> listOfParameterTypes,
      List<String> listOfParameterNames,
      List<Object> listOfArgs
    ) {
      recordInvocation(stubbedMethodName, listOfArgs);
      throwConfiguredFailure(stubbedMethodName);
      if (forwardUpdates && stubbedMethodName == 'doUpdate') {
        return new CKR_DefaultDmlGateway().doUpdate(
          (List<SObject>) listOfArgs[0],
          (CKR_DmlMode) listOfArgs[1]
        );
      }
      return configuredResponse(stubbedMethodName);
    }

    private void recordInvocation(
      String stubbedMethodName,
      List<Object> listOfArgs
    ) {
      if (!invocations.containsKey(stubbedMethodName)) {
        invocations.put(stubbedMethodName, new List<List<Object>>());
      }
      invocations.get(stubbedMethodName).add(listOfArgs);
      if (idAssigningMethods.contains(stubbedMethodName)) {
        for (SObject record : (List<SObject>) listOfArgs[0]) {
          if (record.Id == null) {
            record.put(
              'Id',
              CKR_TestRecords.fakeId(record.getSObjectType(), ++idSequence)
            );
          }
        }
      }
    }

    private void throwConfiguredFailure(String stubbedMethodName) {
      if (
        failures.containsKey(stubbedMethodName)
        && (
          !failureCallNumbers.containsKey(stubbedMethodName)
          || failureCallNumbers.get(stubbedMethodName)
            == callCount(stubbedMethodName)
        )
      ) {
        throw failures.get(stubbedMethodName);
      }
    }

    private Object configuredResponse(String stubbedMethodName) {
      if (responseSequences.containsKey(stubbedMethodName)) {
        List<Object> sequence = responseSequences.get(stubbedMethodName);
        Integer callIndex = invocations.get(stubbedMethodName).size() - 1;
        return sequence[Math.min(callIndex, sequence.size() - 1)];
      }
      return responses.get(stubbedMethodName);
    }

    /**
     * Returns the call count.
     * @param methodName Value used by this operation.
     * @return Value produced by this operation.
     */
    public Integer callCount(String methodName) {
      if (!invocations.containsKey(methodName)) {
        return 0;
      }
      return invocations.get(methodName).size();
    }

    /**
     * Returns the last arguments.
     * @param methodName Value used by this operation.
     * @return Value produced by this operation.
     */
    public List<Object> lastArguments(String methodName) {
      List<List<Object>> methodInvocations = invocations.get(methodName);
      if (methodInvocations == null || methodInvocations.isEmpty()) {
        return new List<Object>();
      }
      return methodInvocations[methodInvocations.size() - 1];
    }

    /**
     * Returns the arguments at.
     * @param methodName Value used by this operation.
     * @param index Value used by this operation.
     * @return Value produced by this operation.
     */
    public List<Object> argumentsAt(String methodName, Integer index) {
      List<List<Object>> methodInvocations = invocations.get(methodName);
      if (
        methodInvocations == null
        || index == null
        || index < 0
        || index >= methodInvocations.size()
      ) {
        return new List<Object>();
      }
      return methodInvocations[index];
    }
  }
}
