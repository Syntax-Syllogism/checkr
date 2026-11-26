/**
 * DML seam used by services and controllers so writes can be stubbed in unit tests.
 */
public interface CKR_IDmlGateway {
  /**
   * Inserts records.
   *
   * @param records records to insert; null or empty is a no-op
   * @param mode batch failure policy; null uses ALL_OR_NONE
   * @return save results, empty when nothing was inserted
   */
  List<Database.SaveResult> doInsert(List<SObject> records, CKR_DmlMode mode);

  /**
   * Updates records.
   *
   * @param records records to update; null or empty is a no-op
   * @param mode batch failure policy; null uses ALL_OR_NONE
   * @return save results, empty when nothing was updated
   */
  List<Database.SaveResult> doUpdate(List<SObject> records, CKR_DmlMode mode);

  /**
   * Deletes records.
   *
   * @param records records to delete; null or empty is a no-op
   * @param mode batch failure policy; null uses ALL_OR_NONE
   * @return delete results, empty when nothing was deleted
   */
  List<Database.DeleteResult> doDelete(List<SObject> records, CKR_DmlMode mode);
}
