/**
 * Provides selector base behavior. Reads run in user mode by default; the
 * documented system-mode exceptions use querySystemModeWithBinds.
 */
public abstract with sharing class CKR_SelectorBase {
  /**
   * Runs a bound query in user mode.
   *
   * @param soql constant query string
   * @param binds bind variables referenced by the query
   * @return matching records
   */
  protected List<SObject> queryWithBinds(
    String soql,
    Map<String, Object> binds
  ) {
    return Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
  }

  /**
   * Runs a bound COUNT() query in user mode.
   *
   * @param soql constant COUNT() query string
   * @param binds bind variables referenced by the query
   * @return the count
   */
  protected Integer countWithBinds(String soql, Map<String, Object> binds) {
    return Database.countQueryWithBinds(soql, binds, AccessLevel.USER_MODE);
  }

  /**
   * Runs a bound query in system mode. Reserved for the documented exceptions
   * in docs/architecture.md.
   *
   * @param soql constant query string
   * @param binds bind variables referenced by the query
   * @return matching records
   */
  protected List<SObject> querySystemModeWithBinds(
    String soql,
    Map<String, Object> binds
  ) {
    return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
  }
}
