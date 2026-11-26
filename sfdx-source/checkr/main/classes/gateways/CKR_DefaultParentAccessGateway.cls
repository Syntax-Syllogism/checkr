/**
 * Production parent access gateway backed by UserRecordAccess and FeatureManagement.
 */
public with sharing class CKR_DefaultParentAccessGateway
  extends CKR_SelectorBase implements CKR_IParentAccessGateway {
  private static final String PARENT_ACCESS_SOQL =
    'SELECT RecordId, HasReadAccess, HasEditAccess FROM UserRecordAccess '
    + 'WHERE UserId = :userId AND RecordId IN :parentRecordIds';

  /**
   * Loads read/edit access for parent records for the running user.
   *
   * @param parentRecordIds parent record ids to inspect
   * @return parent access keyed by parent record id
   */
  public Map<Id, CKR_ParentAccess> loadParentAccess(Set<Id> parentRecordIds) {
    Map<Id, CKR_ParentAccess> accessByParentId =
      new Map<Id, CKR_ParentAccess>();
    if (parentRecordIds == null || parentRecordIds.isEmpty()) {
      return accessByParentId;
    }

    for (UserRecordAccess accessRecord : (List<UserRecordAccess>) queryWithBinds(
      PARENT_ACCESS_SOQL,
      new Map<String, Object>{
        'userId' => UserInfo.getUserId(),
        'parentRecordIds' => parentRecordIds
      }
    )) {
      accessByParentId.put(
        accessRecord.RecordId,
        new CKR_ParentAccess(parentAccessLevel(accessRecord))
      );
    }

    return accessByParentId;
  }

  private CKR_ParentAccessLevel parentAccessLevel(
    UserRecordAccess accessRecord
  ) {
    if (accessRecord.HasEditAccess) {
      return CKR_ParentAccessLevel.EDIT;
    }
    return accessRecord.HasReadAccess
    ? CKR_ParentAccessLevel.READ
    : CKR_ParentAccessLevel.NONE;
  }

  /**
   * Checks whether the running user has a named custom permission.
   *
   * @param customPermissionDeveloperName custom permission developer name
   * @return true when the running user has the custom permission
   */
  public Boolean hasCustomPermission(String customPermissionDeveloperName) {
    return !String.isBlank(customPermissionDeveloperName)
      && FeatureManagement.checkPermission(customPermissionDeveloperName);
  }
}
