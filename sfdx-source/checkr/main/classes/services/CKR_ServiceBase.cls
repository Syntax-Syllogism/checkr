/**
 * Provides typed dependency accessors for services. Services resolve their
 * collaborators through these methods and never construct them directly.
 */
public abstract with sharing class CKR_ServiceBase implements CKR_IService {
  protected CKR_IDmlGateway dmlGateway() {
    return (CKR_IDmlGateway) CKR_AppFactory.getInstance(CKR_IDmlGateway.class);
  }

  protected CKR_ISystemDmlGateway systemDmlGateway() {
    return (CKR_ISystemDmlGateway) CKR_AppFactory.getInstance(
      CKR_ISystemDmlGateway.class
    );
  }

  protected CKR_IChecklistInstanceSelector checklistInstanceSelector() {
    return (CKR_IChecklistInstanceSelector) CKR_AppFactory.getInstance(
      CKR_IChecklistInstanceSelector.class
    );
  }

  protected CKR_IChecklistGateSelector checklistGateSelector() {
    return (CKR_IChecklistGateSelector) CKR_AppFactory.getInstance(
      CKR_IChecklistGateSelector.class
    );
  }

  protected CKR_ISupportedObjectSelector supportedObjectSelector() {
    return (CKR_ISupportedObjectSelector) CKR_AppFactory.getInstance(
      CKR_ISupportedObjectSelector.class
    );
  }

  protected CKR_IParentAccessGateway parentAccessGateway() {
    return (CKR_IParentAccessGateway) CKR_AppFactory.getInstance(
      CKR_IParentAccessGateway.class
    );
  }

  protected CKR_IChecklistAuditService auditService() {
    return (CKR_IChecklistAuditService) CKR_AppFactory.getInstance(
      CKR_IChecklistAuditService.class
    );
  }
}
