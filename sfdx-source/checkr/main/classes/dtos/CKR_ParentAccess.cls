/**
 * Immutable value object representing the running user's access to a parent record.
 */
public class CKR_ParentAccess {
  /**
   * Whether the current user can read the checklist’s parent record.
   */
  public Boolean hasReadAccess { get; private set; }
  /**
   * Whether the current user can edit the checklist’s parent record.
   */
  public Boolean hasEditAccess { get; private set; }

  /**
   * Creates a parent access snapshot.
   *
   * @param level strongest access granted to the user
   */
  public CKR_ParentAccess(CKR_ParentAccessLevel level) {
    hasReadAccess =
      level == CKR_ParentAccessLevel.READ
      || level == CKR_ParentAccessLevel.EDIT;
    hasEditAccess = level == CKR_ParentAccessLevel.EDIT;
  }
}
