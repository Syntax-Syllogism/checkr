/**
 * Production DML gateway that runs DML in user mode.
 */
public with sharing class CKR_DefaultDmlGateway implements CKR_IDmlGateway {
  /**
   * Inserts records in user mode.
   *
   * @param records records to insert; null or empty is a no-op
   * @param mode batch failure policy; null uses ALL_OR_NONE
   * @return save results, empty when nothing was inserted
   */
  public List<Database.SaveResult> doInsert(
    List<SObject> records,
    CKR_DmlMode mode
  ) {
    if (records == null || records.isEmpty()) {
      return new List<Database.SaveResult>();
    }
    return Database.insert(
      records,
      mode != CKR_DmlMode.PARTIAL,
      AccessLevel.USER_MODE
    );
  }

  /**
   * Updates records in user mode.
   *
   * @param records records to update; null or empty is a no-op
   * @param mode batch failure policy; null uses ALL_OR_NONE
   * @return save results, empty when nothing was updated
   */
  public List<Database.SaveResult> doUpdate(
    List<SObject> records,
    CKR_DmlMode mode
  ) {
    if (records == null || records.isEmpty()) {
      return new List<Database.SaveResult>();
    }
    return Database.update(
      records,
      mode != CKR_DmlMode.PARTIAL,
      AccessLevel.USER_MODE
    );
  }

  /**
   * Deletes records in user mode.
   *
   * @param records records to delete; null or empty is a no-op
   * @param mode batch failure policy; null uses ALL_OR_NONE
   * @return delete results, empty when nothing was deleted
   */
  public List<Database.DeleteResult> doDelete(
    List<SObject> records,
    CKR_DmlMode mode
  ) {
    if (records == null || records.isEmpty()) {
      return new List<Database.DeleteResult>();
    }
    return Database.delete(
      records,
      mode != CKR_DmlMode.PARTIAL,
      AccessLevel.USER_MODE
    );
  }
}
