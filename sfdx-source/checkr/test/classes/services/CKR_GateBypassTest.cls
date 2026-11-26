@IsTest
private class CKR_GateBypassTest {
  @IsTest
  static void noSwitchReturnsNull() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      System.Assert.isNull(new CKR_GateBypass().source());
    }
  }

  @IsTest
  static void hierarchySettingIsCached_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      CKR_Settings__c setting =
        new CKR_Settings__c(
          SetupOwnerId = UserInfo.getUserId(),
          CKR_BypassGate__c = true
        );
      insert setting;
      System.Assert.areEqual('CustomSetting', new CKR_GateBypass().source());
      setting.CKR_BypassGate__c = false;
      update setting;
      System.Assert.areEqual(
          'CustomSetting',
          new CKR_GateBypass().source(),
          'Resolution is cached for the transaction.'
        );
    }
  }

  @IsTest
  static void profileAndUserOverrideOrg_integrationHappyPath() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert new CKR_Settings__c(
        SetupOwnerId = UserInfo.getOrganizationId(),
        CKR_BypassGate__c = true
      );
      System.Assert.isTrue(CKR_Settings__c.getInstance().CKR_BypassGate__c);
      insert new CKR_Settings__c(
        SetupOwnerId = UserInfo.getProfileId(),
        CKR_BypassGate__c = false
      );
      System.Assert.isFalse(
          CKR_Settings__c.getInstance().CKR_BypassGate__c,
          'Profile overrides org.'
        );
      insert new CKR_Settings__c(
        SetupOwnerId = UserInfo.getUserId(),
        CKR_BypassGate__c = true
      );
      System.Assert.areEqual(
          'CustomSetting',
          new CKR_GateBypass().source(),
          'User overrides profile.'
        );
    }
  }
}
