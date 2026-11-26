/**
 * Caches the effective bypass switch per running user for this transaction.
 */
public inherited sharing class CKR_GateBypass
  extends CKR_ServiceBase implements CKR_IGateBypass {
  private static Map<Id, String> sourcesByUser = new Map<Id, String>();

  /**
   * Resolves the enabled gate bypass in precedence order for the running user.
   * @return the bypass source, or null when enforcement applies
   */
  public String source() {
    Id actor = UserInfo.getUserId();
    if (!sourcesByUser.containsKey(actor)) {
      String activeSource;
      if (FeatureManagement.checkPermission('CKR_BypassGate')) {
        activeSource = 'CustomPermission';
      } else if (CKR_Settings__c.getInstance().CKR_BypassGate__c == true) {
        activeSource = 'CustomSetting';
      }
      sourcesByUser.put(actor, activeSource);
    }
    return sourcesByUser.get(actor);
  }
}
