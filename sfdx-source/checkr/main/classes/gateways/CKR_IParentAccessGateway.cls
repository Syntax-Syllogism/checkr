/**
 * Gateway for parent-record sharing and custom-permission checks.
 */
public interface CKR_IParentAccessGateway {
  /**
   * Loads read/edit access for parent records for the running user.
   *
   * @param parentRecordIds parent record ids to inspect
   * @return parent access keyed by parent record id
   */
  Map<Id, CKR_ParentAccess> loadParentAccess(Set<Id> parentRecordIds);

  /**
   * Checks whether the running user has a named custom permission.
   *
   * @param customPermissionDeveloperName custom permission developer name
   * @return true when the running user has the custom permission
   */
  Boolean hasCustomPermission(String customPermissionDeveloperName);
}
