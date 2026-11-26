/**
 * Marker DML seam for system-authored writes that must bypass the running
 * user's CRUD/FLS. It exists only as a separate factory key so audit writes
 * can be stubbed independently of user-mode writes.
 */
public interface CKR_ISystemDmlGateway extends CKR_IDmlGateway {
}
