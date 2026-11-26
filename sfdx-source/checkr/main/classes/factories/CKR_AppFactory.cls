/**
 * Provides configured app dependencies. Production code resolves every
 * selector, gateway, and service through this single type-keyed registry.
 */
public with sharing class CKR_AppFactory {
  private static final Map<Type, Type> DEFAULTS =
    new Map<Type, Type>{
      CKR_IAuditRetentionSelector.class => CKR_AuditRetentionSelector.class,
      CKR_IChecklistTemplateVersionSelector.class => CKR_ChecklistTemplateVersionSelector.class,
      CKR_IChecklistTemplateVersionService.class => CKR_DefaultTemplateVersionService.class,
      CKR_ITemplateVersionLifecycleService.class => CKR_TemplateVersionLifecycleService.class,
      CKR_ISupportedObjectSelector.class => CKR_DefaultSupportedObjectSelector.class,
      CKR_IChecklistGateSelector.class => CKR_ChecklistGateSelector.class,
      CKR_IChecklistCreateContextSelector.class => CKR_ChecklistCreateContextSelector.class,
      CKR_IChecklistViewerSelector.class => CKR_ChecklistViewerSelector.class,
      CKR_IParentAccessGateway.class => CKR_DefaultParentAccessGateway.class,
      CKR_IDmlGateway.class => CKR_DefaultDmlGateway.class,
      CKR_ISystemDmlGateway.class => CKR_SystemModeDmlGateway.class,
      CKR_IChecklistInstanceSelector.class => CKR_DefaultChecklistInstanceSelector.class,
      CKR_IChecklistMutationSelector.class => CKR_DefaultChecklistMutationSelector.class,
      CKR_IGateBypass.class => CKR_GateBypass.class,
      CKR_IChecklistGateService.class => CKR_DefaultChecklistGateService.class,
      CKR_IChecklistInstanceService.class => CKR_DefaultChecklistInstanceService.class,
      CKR_IChecklistPermissionService.class => CKR_DefaultChecklistPermissionService.class,
      CKR_IChecklistAuditService.class => CKR_DefaultChecklistAuditService.class
    };

  @TestVisible
  private static Map<Type, Object> overrides = new Map<Type, Object>();

  /**
   * Returns the registered instance for a port type.
   *
   * @param requestedType interface type to resolve
   * @return the test override when one is set, otherwise the default implementation
   */
  public static Object getInstance(Type requestedType) {
    if (overrides.containsKey(requestedType)) {
      return overrides.get(requestedType);
    }
    return defaultFor(requestedType);
  }

  @TestVisible
  private static void setMock(Type requestedType, Object stub) {
    overrides.put(requestedType, stub);
  }

  @TestVisible
  private static void clearMocks() {
    overrides.clear();
  }

  private static Object defaultFor(Type requestedType) {
    Type implementation = DEFAULTS.get(requestedType);
    if (implementation != null) {
      return implementation.newInstance();
    }
    throw new CKR_AppFactoryException(
      'No application implementation registered for ' + requestedType
    );
  }
}
