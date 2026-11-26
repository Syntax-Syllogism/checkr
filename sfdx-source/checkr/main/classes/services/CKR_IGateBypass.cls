/**
 * Resolves the active gate bypass switch, or null when neither is enabled.
 */
public interface CKR_IGateBypass {
  /**
   * Resolves the enabled gate bypass in precedence order for the running user.
   * @return the bypass source, or null when enforcement applies
   */
  String source();
}
