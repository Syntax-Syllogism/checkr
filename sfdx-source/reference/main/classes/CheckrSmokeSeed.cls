public inherited sharing class CheckrSmokeSeed {
  public class SeedException extends Exception {
  }

  private static final String ACCOUNT_PREFIX = 'Checkr Smoke - ';

  private static Map<String, Account> accountsByKey =
    new Map<String, Account>();
  private static Map<String, CKR_ChecklistTemplate__c> templatesByKey =
    new Map<String, CKR_ChecklistTemplate__c>();
  private static Map<String, CKR_ChecklistTemplateVersion__c> versionsByKey =
    new Map<String, CKR_ChecklistTemplateVersion__c>();
  private static Map<String, Id> instancesByKey = new Map<String, Id>();
  private static Map<String, User> smokeUsersByPersona =
    new Map<String, User>();

  public static void run() {
    loadSmokeUsers();
    resetData();
    createAccounts();
    createTemplates();
    createVersions();
    createTemplateItems();
    createGateRules();
    publishVersions();
    createChecklistInstances();
    System.debug(buildSummary());
  }

  private static void resetData() {
    List<CKR_ChecklistTemplate__c> templatesToClear = [
      SELECT Id, CKR_CurrentPublishedVersion__c
      FROM CKR_ChecklistTemplate__c
    ];
    for (CKR_ChecklistTemplate__c templateRecord : templatesToClear) {
      templateRecord.CKR_CurrentPublishedVersion__c = null;
    }
    if (!templatesToClear.isEmpty()) {
      update templatesToClear;
    }

    List<CKR_ChecklistInstance__c> instanceRecords = [
      SELECT Id
      FROM CKR_ChecklistInstance__c
    ];
    if (!instanceRecords.isEmpty()) {
      delete instanceRecords;
    }

    List<CKR_ChecklistGateRule__c> gateRules = [
      SELECT Id
      FROM CKR_ChecklistGateRule__c
    ];
    if (!gateRules.isEmpty()) {
      delete gateRules;
    }

    List<CKR_ChecklistTemplateItem__c> templateItems = [
      SELECT Id
      FROM CKR_ChecklistTemplateItem__c
    ];
    if (!templateItems.isEmpty()) {
      delete templateItems;
    }

    List<CKR_ChecklistTemplateVersion__c> templateVersions = [
      SELECT Id
      FROM CKR_ChecklistTemplateVersion__c
    ];
    if (!templateVersions.isEmpty()) {
      delete templateVersions;
    }

    List<CKR_ChecklistTemplate__c> templateRecords = [
      SELECT Id
      FROM CKR_ChecklistTemplate__c
    ];
    if (!templateRecords.isEmpty()) {
      delete templateRecords;
    }

    List<Account> smokeAccounts = [
      SELECT Id
      FROM Account
      WHERE Name LIKE :(ACCOUNT_PREFIX + '%')
    ];
    if (!smokeAccounts.isEmpty()) {
      delete smokeAccounts;
    }
  }

  private static void createAccounts() {
    Id adminUserId =
      smokeUsersByPersona.get(CheckrSmokeUserSeed.PERSONA_ADMIN).Id;
    List<Account> accountRecords =
      new List<Account>{
        new Account(
          Name = ACCOUNT_PREFIX + 'Redwood Health - ReadAccess Template',
          OwnerId = adminUserId,
          Type = 'Customer - Direct',
          Industry = 'Healthcare',
          Rating = 'Warm'
        ),
        new Account(
          Name = ACCOUNT_PREFIX + 'Bluebird Logistics - ReadAccess Template',
          OwnerId = adminUserId,
          Type = 'Prospect',
          Industry = 'Transportation',
          Rating = 'Cold'
        ),
        new Account(
          Name =
            ACCOUNT_PREFIX + 'Northstar Manufacturing - EditAccess Template',
          OwnerId = adminUserId,
          Type = 'Customer - Channel',
          Industry = 'Manufacturing',
          Rating = 'Warm'
        ),
        new Account(
          Name = ACCOUNT_PREFIX + 'Summit Services - CustomPermission Template',
          OwnerId = adminUserId,
          Type = 'Partner',
          Industry = 'Consulting',
          Rating = 'Hot'
        ),
        new Account(
          Name = ACCOUNT_PREFIX + 'No Checklist - Control Record',
          OwnerId = adminUserId,
          Type = 'Prospect',
          Industry = 'Technology',
          Rating = 'Warm'
        )
      };
    insert accountRecords;

    accountsByKey.put('redwood', accountRecords[0]);
    accountsByKey.put('bluebird', accountRecords[1]);
    accountsByKey.put('northstar', accountRecords[2]);
    accountsByKey.put('summit', accountRecords[3]);
    accountsByKey.put('empty', accountRecords[4]);

    createAccountShares();
  }

  private static void createTemplates() {
    List<CKR_ChecklistTemplate__c> templateRecords =
      new List<CKR_ChecklistTemplate__c>{
        new CKR_ChecklistTemplate__c(
          Name = 'Account Onboarding',
          CKR_DeveloperName__c = 'Smoke_Account_Onboarding',
          CKR_SupportedObjectDeveloperName__c = 'Account',
          CKR_TargetObjectApiName__c = 'Account',
          CKR_Description__c = 'Smoke-test onboarding checklist for Accounts.',
          CKR_Active__c = true
        ),
        new CKR_ChecklistTemplate__c(
          Name = 'Renewal Readiness',
          CKR_DeveloperName__c = 'Smoke_Renewal_Readiness',
          CKR_SupportedObjectDeveloperName__c = 'Account',
          CKR_TargetObjectApiName__c = 'Account',
          CKR_Description__c = 'Smoke-test renewal checklist for Accounts.',
          CKR_Active__c = true
        ),
        new CKR_ChecklistTemplate__c(
          Name = 'Compliance Review',
          CKR_DeveloperName__c = 'Smoke_Compliance_Review',
          CKR_SupportedObjectDeveloperName__c = 'Account',
          CKR_TargetObjectApiName__c = 'Account',
          CKR_Description__c = 'Smoke-test compliance checklist for Accounts.',
          CKR_Active__c = true
        )
      };
    insert templateRecords;

    templatesByKey.put('onboarding', templateRecords[0]);
    templatesByKey.put('renewal', templateRecords[1]);
    templatesByKey.put('compliance', templateRecords[2]);
  }

  private static void createVersions() {
    List<CKR_ChecklistTemplateVersion__c> versionRecords =
      new List<CKR_ChecklistTemplateVersion__c>{
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = templatesByKey.get('onboarding').Id,
          CKR_Status__c = 'Draft',
          CKR_VersionNumber__c = 1,
          CKR_CompletionAccessMode__c = 'ReadAccess',
          CKR_Description__c = 'Onboarding version published by the smoke seed.'
        ),
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = templatesByKey.get('renewal').Id,
          CKR_Status__c = 'Draft',
          CKR_VersionNumber__c = 1,
          CKR_CompletionAccessMode__c = 'EditAccess',
          CKR_Description__c = 'Renewal version published by the smoke seed.'
        ),
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = templatesByKey.get('compliance').Id,
          CKR_Status__c = 'Draft',
          CKR_VersionNumber__c = 1,
          CKR_CompletionAccessMode__c = 'CustomPermission',
          CKR_CustomPermissionDeveloperName__c = 'CKR_Smoke_Compliance_Update',
          CKR_Description__c = 'Compliance version published by the smoke seed.'
        ),
        new CKR_ChecklistTemplateVersion__c(
          CKR_ChecklistTemplate__c = templatesByKey.get('compliance').Id,
          CKR_Status__c = 'Draft',
          CKR_VersionNumber__c = 2,
          CKR_CompletionAccessMode__c = 'CustomPermission',
          CKR_CustomPermissionDeveloperName__c = 'CKR_Smoke_Compliance_Update',
          CKR_Description__c =
            'Draft follow-on version to prove version filtering.'
        )
      };
    insert versionRecords;

    versionsByKey.put('onboardingPublished', versionRecords[0]);
    versionsByKey.put('renewalPublished', versionRecords[1]);
    versionsByKey.put('compliancePublished', versionRecords[2]);
    versionsByKey.put('complianceDraft', versionRecords[3]);
  }

  // Direct writes to Published are rejected, so versions start as Draft and
  // publish through the service once their items and gate rules exist.
  private static void publishVersions() {
    CKR_IChecklistTemplateVersionService versionService =
      (CKR_IChecklistTemplateVersionService) CKR_AppFactory.getInstance(
        CKR_IChecklistTemplateVersionService.class
      );
    for (String key : new List<String>{
      'onboardingPublished',
      'renewalPublished',
      'compliancePublished'
    }) {
      versionService.publish(versionsByKey.get(key).Id);
    }
  }

  private static void createTemplateItems() {
    insert new List<CKR_ChecklistTemplateItem__c>{
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('onboardingPublished').Id,
        CKR_Active__c = true,
        CKR_Label__c = 'Confirm executive sponsor',
        CKR_ExplanationInputType__c = 'Text',
        CKR_Required__c = true,
        CKR_ExplanationRequired__c = true,
        CKR_SortOrder__c = 1
      ),
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('onboardingPublished').Id,
        CKR_Active__c = true,
        CKR_Label__c = 'Select billing profile',
        CKR_ExplanationInputType__c = 'Picklist',
        CKR_ExplanationPicklistValues__c =
          'Standard Billing;Enterprise Billing;Partner Billing',
        CKR_Required__c = true,
        CKR_ExplanationRequired__c = false,
        CKR_SortOrder__c = 2
      ),
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('onboardingPublished').Id,
        CKR_Active__c = true,
        CKR_Label__c = 'Capture kickoff notes',
        CKR_ExplanationInputType__c = 'Text',
        CKR_Required__c = false,
        CKR_ExplanationRequired__c = true,
        CKR_SortOrder__c = 3
      ),
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('renewalPublished').Id,
        CKR_Active__c = true,
        CKR_Label__c = 'Validate renewal amount',
        CKR_ExplanationInputType__c = 'Text',
        CKR_Required__c = true,
        CKR_ExplanationRequired__c = false,
        CKR_SortOrder__c = 1
      ),
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('renewalPublished').Id,
        CKR_Active__c = true,
        CKR_Label__c = 'Choose renewal risk',
        CKR_ExplanationInputType__c = 'Picklist',
        CKR_ExplanationPicklistValues__c = 'Low Risk;Medium Risk;High Risk',
        CKR_Required__c = true,
        CKR_ExplanationRequired__c = false,
        CKR_SortOrder__c = 2
      ),
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('renewalPublished').Id,
        CKR_Active__c = true,
        CKR_Label__c = 'Confirm legal terms',
        CKR_ExplanationInputType__c = 'Text',
        CKR_Required__c = false,
        CKR_ExplanationRequired__c = true,
        CKR_SortOrder__c = 3
      ),
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('compliancePublished').Id,
        CKR_Active__c = true,
        CKR_Label__c = 'Verify KYC documents',
        CKR_ExplanationInputType__c = 'Text',
        CKR_Required__c = true,
        CKR_ExplanationRequired__c = false,
        CKR_SortOrder__c = 1
      ),
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('compliancePublished').Id,
        CKR_Active__c = true,
        CKR_Label__c = 'Sanctions screening outcome',
        CKR_ExplanationInputType__c = 'Picklist',
        CKR_ExplanationPicklistValues__c = 'Clear;Review Required',
        CKR_Required__c = true,
        CKR_ExplanationRequired__c = true,
        CKR_SortOrder__c = 2
      ),
      new CKR_ChecklistTemplateItem__c(
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('compliancePublished').Id,
        CKR_Active__c = true,
        CKR_Label__c = 'Escalation noted',
        CKR_ExplanationInputType__c = 'Text',
        CKR_Required__c = false,
        CKR_ExplanationRequired__c = true,
        CKR_SortOrder__c = 3
      )
    };
  }

  private static void createGateRules() {
    insert new List<CKR_ChecklistGateRule__c>{
      new CKR_ChecklistGateRule__c(
        Name = 'Onboarding Industry Change Gate',
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('onboardingPublished').Id,
        CKR_Active__c = true,
        CKR_ProtectedActionType__c = 'AnyFieldValueChange',
        CKR_TargetFieldApiName__c = 'Industry',
        CKR_ErrorMessage__c =
          'Complete the onboarding checklist before changing Industry.',
        CKR_SortOrder__c = 1
      ),
      new CKR_ChecklistGateRule__c(
        Name = 'Onboarding Customer Type Gate',
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('onboardingPublished').Id,
        CKR_Active__c = true,
        CKR_ProtectedActionType__c = 'SpecificFieldValueChange',
        CKR_TargetFieldApiName__c = 'Type',
        CKR_TargetValue__c = 'Customer - Direct',
        CKR_ErrorMessage__c =
          'Complete onboarding before marking the account Customer - Direct.',
        CKR_SortOrder__c = 2
      ),
      new CKR_ChecklistGateRule__c(
        Name = 'Renewal Hot Rating Gate',
        CKR_ChecklistTemplateVersion__c =
          versionsByKey.get('renewalPublished').Id,
        CKR_Active__c = true,
        CKR_ProtectedActionType__c = 'SpecificFieldValueChange',
        CKR_TargetFieldApiName__c = 'Rating',
        CKR_TargetValue__c = 'Hot',
        CKR_TargetValueSet__c = 'Warm\nHot',
        CKR_ErrorMessage__c =
          'Complete renewal readiness before moving Rating to Hot.',
        CKR_SortOrder__c = 1
      )
    };
  }

  private static void createChecklistInstances() {
    Id redwoodOnboardingId =
      createInstance(
        'redwoodOnboarding',
        'onboardingPublished',
        accountsByKey.get('redwood').Id,
        Date.today().addDays(14)
      );
    setTemplateItemState(
      redwoodOnboardingId,
      'Confirm executive sponsor',
      true,
      'Sponsor confirmed in kickoff call.'
    );
    setTemplateItemState(
      redwoodOnboardingId,
      'Select billing profile',
      true,
      'Enterprise Billing'
    );
    addAdHocItem(
      redwoodOnboardingId,
      'Capture VAT certificate',
      'Text',
      null,
      false,
      false,
      null
    );
    recalcInstance(redwoodOnboardingId);

    Id bluebirdOnboardingId =
      createInstance(
        'bluebirdOnboarding',
        'onboardingPublished',
        accountsByKey.get('bluebird').Id,
        Date.today().addDays(-5)
      );
    setTemplateItemState(
      bluebirdOnboardingId,
      'Confirm executive sponsor',
      true,
      'Sponsor confirmed, billing still pending.'
    );
    recalcInstance(bluebirdOnboardingId);

    Id northstarRenewalId =
      createInstance(
        'northstarRenewal',
        'renewalPublished',
        accountsByKey.get('northstar').Id,
        Date.today().addDays(3)
      );
    setTemplateItemState(
      northstarRenewalId,
      'Validate renewal amount',
      true,
      null
    );
    addAdHocItem(
      northstarRenewalId,
      'Executive review required',
      'Picklist',
      'Yes;No',
      true,
      true,
      'VP review scheduled.'
    );
    recalcInstance(northstarRenewalId);

    Id summitComplianceId =
      createInstance(
        'summitCompliance',
        'compliancePublished',
        accountsByKey.get('summit').Id,
        Date.today().addDays(7)
      );
    setTemplateItemState(
      summitComplianceId,
      'Verify KYC documents',
      true,
      null
    );
    setTemplateItemState(
      summitComplianceId,
      'Sanctions screening outcome',
      true,
      'Screening completed with no findings.'
    );
    recalcInstance(summitComplianceId);
  }

  private static Id createInstance(
    String instanceKey,
    String versionKey,
    Id parentRecordId,
    Date dueDate
  ) {
    CKR_ChecklistInstanceCreateRequest request =
      new CKR_ChecklistInstanceCreateRequest();
    request.templateVersionId = versionsByKey.get(versionKey).Id;
    request.parentRecordId = parentRecordId;
    request.parentObjectApiName = 'Account';
    request.dueDate = dueDate;

    CKR_ChecklistInstanceCreateResult result =
      new CKR_DefaultChecklistInstanceService().createFromTemplate(request);
    if (
      result == null
      || result.success != true
      || result.checklistInstanceId == null
    ) {
      throw new SeedException(
        'Failed to create instance '
        + instanceKey
        + ': '
        + String.join(
          result == null
          ? new List<String>{ 'Unknown error' }
          : result.messages,
          ' | '
        )
      );
    }

    instancesByKey.put(instanceKey, result.checklistInstanceId);
    return result.checklistInstanceId;
  }

  private static void setTemplateItemState(
    Id instanceId,
    String label,
    Boolean checkboxValue,
    String explanation
  ) {
    List<CKR_ChecklistInstanceItem__c> itemRecords = [
      SELECT
        Id,
        CKR_CheckboxValue__c,
        CKR_Explanation__c,
        CKR_ExplanationRequired__c,
        CKR_Completed__c
      FROM CKR_ChecklistInstanceItem__c
      WHERE CKR_ChecklistInstance__c = :instanceId AND CKR_Label__c = :label
      LIMIT 1
    ];
    if (itemRecords.isEmpty()) {
      throw new SeedException('Missing template item for label: ' + label);
    }

    CKR_ChecklistInstanceItem__c itemRecord = itemRecords[0];
    itemRecord.CKR_CheckboxValue__c = checkboxValue == true;
    itemRecord.CKR_Explanation__c = explanation;
    itemRecord.CKR_Completed__c = isComplete(itemRecord);
    if (itemRecord.CKR_Completed__c) {
      itemRecord.CKR_CompletedBy__c = UserInfo.getUserId();
      itemRecord.CKR_CompletedOn__c = System.now();
    } else {
      itemRecord.CKR_CompletedBy__c = null;
      itemRecord.CKR_CompletedOn__c = null;
    }
    update itemRecord;
  }

  private static void addAdHocItem(
    Id instanceId,
    String label,
    String explanationInputType,
    String explanationPicklistValues,
    Boolean explanationRequired,
    Boolean completed,
    String explanation
  ) {
    Decimal nextSortOrder = 1;
    AggregateResult[] sortResults = [
      SELECT MAX(CKR_SortOrder__c) maxSort
      FROM CKR_ChecklistInstanceItem__c
      WHERE CKR_ChecklistInstance__c = :instanceId
    ];
    if (!sortResults.isEmpty() && sortResults[0].get('maxSort') != null) {
      nextSortOrder = ((Decimal) sortResults[0].get('maxSort')) + 1;
    }

    CKR_ChecklistInstanceItem__c adHocItem =
      new CKR_ChecklistInstanceItem__c(
        CKR_ChecklistInstance__c = instanceId,
        CKR_SourceType__c = 'AdHoc',
        CKR_LockedFromTemplate__c = false,
        CKR_Label__c = label,
        CKR_Required__c = false,
        CKR_ExplanationRequired__c = explanationRequired,
        CKR_ExplanationInputType__c =
          explanationInputType == 'Picklist' ? 'Picklist' : 'Text',
        CKR_ExplanationPicklistValues__c =
          explanationInputType == 'Picklist' ? explanationPicklistValues : null,
        CKR_CheckboxValue__c = completed == true,
        CKR_Explanation__c = explanation,
        CKR_Completed__c = completed == true,
        CKR_SortOrder__c = nextSortOrder
      );
    if (adHocItem.CKR_Completed__c) {
      adHocItem.CKR_CompletedBy__c = UserInfo.getUserId();
      adHocItem.CKR_CompletedOn__c = System.now();
    }
    insert adHocItem;
  }

  private static void recalcInstance(Id instanceId) {
    CKR_ChecklistInstance__c instanceRecord = [
      SELECT Id, CKR_DueDate__c
      FROM CKR_ChecklistInstance__c
      WHERE Id = :instanceId
      LIMIT 1
    ];

    List<CKR_ChecklistInstanceItem__c> itemRecords = [
      SELECT CKR_SourceType__c, CKR_Required__c, CKR_Completed__c
      FROM CKR_ChecklistInstanceItem__c
      WHERE CKR_ChecklistInstance__c = :instanceId
    ];

    Integer requiredCount = 0;
    Integer completedCount = 0;
    for (CKR_ChecklistInstanceItem__c itemRecord : itemRecords) {
      if (
        itemRecord.CKR_SourceType__c == 'Template'
        && itemRecord.CKR_Required__c == true
      ) {
        requiredCount++;
        if (itemRecord.CKR_Completed__c == true) {
          completedCount++;
        }
      }
    }

    Boolean isComplete = requiredCount == 0 || completedCount >= requiredCount;
    Decimal percentComplete =
      requiredCount == 0
      ? 100
      : (((Decimal) completedCount * 100) / requiredCount).setScale(2);

    instanceRecord.CKR_RequiredItemCount__c = requiredCount;
    instanceRecord.CKR_CompletedRequiredItemCount__c = completedCount;
    instanceRecord.CKR_IsComplete__c = isComplete;
    instanceRecord.CKR_PercentComplete__c = percentComplete;
    instanceRecord.CKR_IsOverdue__c =
      instanceRecord.CKR_DueDate__c != null
      && instanceRecord.CKR_DueDate__c < Date.today()
      && !isComplete;
    update instanceRecord;
  }

  private static Boolean isComplete(CKR_ChecklistInstanceItem__c itemRecord) {
    Boolean valueSatisfied = itemRecord.CKR_CheckboxValue__c == true;
    Boolean explanationSatisfied =
      itemRecord.CKR_ExplanationRequired__c != true
      || !String.isBlank(itemRecord.CKR_Explanation__c);
    return valueSatisfied && explanationSatisfied;
  }

  private static void loadSmokeUsers() {
    Map<String, String> usernamesByPersona =
      CheckrSmokeUserSeed.usernamesByPersona();
    Set<String> expectedUsernames = new Set<String>();
    expectedUsernames.addAll(usernamesByPersona.values());

    Map<String, User> usersByUsername = new Map<String, User>();
    for (User userRecord : [
      SELECT Id, Username
      FROM User
      WHERE Username IN :expectedUsernames
    ]) {
      usersByUsername.put(userRecord.Username, userRecord);
    }

    smokeUsersByPersona.clear();
    for (String personaKey : usernamesByPersona.keySet()) {
      String username = usernamesByPersona.get(personaKey);
      if (!usersByUsername.containsKey(username)) {
        throw new SeedException(
          'Missing smoke user "'
          + personaKey
          + '" with username "'
          + username
          + '". Run CheckrSmokeUserSeed.run() first.'
        );
      }
      smokeUsersByPersona.put(personaKey, usersByUsername.get(username));
    }
  }

  private static void createAccountShares() {
    List<AccountShare> sharesToInsert = new List<AccountShare>();

    addShare(
      sharesToInsert,
      accountsByKey.get('redwood').Id,
      smokeUsersByPersona.get(CheckrSmokeUserSeed.PERSONA_READ_ONLY).Id,
      'Read'
    );
    addShare(
      sharesToInsert,
      accountsByKey.get('redwood').Id,
      smokeUsersByPersona.get(CheckrSmokeUserSeed.PERSONA_COMPLETER).Id,
      'Read'
    );
    addShare(
      sharesToInsert,
      accountsByKey.get('northstar').Id,
      smokeUsersByPersona.get(CheckrSmokeUserSeed.PERSONA_COMPLETER).Id,
      'Edit'
    );
    addShare(
      sharesToInsert,
      accountsByKey.get('summit').Id,
      smokeUsersByPersona.get(CheckrSmokeUserSeed.PERSONA_COMPLETER).Id,
      'Edit'
    );
    addShare(
      sharesToInsert,
      accountsByKey.get('summit').Id,
      smokeUsersByPersona.get(CheckrSmokeUserSeed.PERSONA_COMPLIANCE).Id,
      'Edit'
    );
    addShare(
      sharesToInsert,
      accountsByKey.get('empty').Id,
      smokeUsersByPersona.get(CheckrSmokeUserSeed.PERSONA_READ_ONLY).Id,
      'Read'
    );

    if (!sharesToInsert.isEmpty()) {
      insert sharesToInsert;
    }
  }

  private static void addShare(
    List<AccountShare> sharesToInsert,
    Id accountId,
    Id userId,
    String accountAccessLevel
  ) {
    if (
      accountId == null || userId == null || String.isBlank(accountAccessLevel)
    ) {
      return;
    }

    sharesToInsert.add(
      new AccountShare(
        AccountId = accountId,
        UserOrGroupId = userId,
        AccountAccessLevel = accountAccessLevel,
        OpportunityAccessLevel = 'Read',
        CaseAccessLevel = 'Read',
        RowCause = Schema.AccountShare.RowCause.Manual
      )
    );
  }

  private static String buildSummary() {
    return 'Checkr smoke data seeded. Accounts='
      + [SELECT COUNT() FROM Account WHERE Name LIKE :(ACCOUNT_PREFIX + '%')]
      + ', Templates='
      + [SELECT COUNT() FROM CKR_ChecklistTemplate__c]
      + ', Versions='
      + [SELECT COUNT() FROM CKR_ChecklistTemplateVersion__c]
      + ', Gates='
      + [SELECT COUNT() FROM CKR_ChecklistGateRule__c]
      + ', Instances='
      + [SELECT COUNT() FROM CKR_ChecklistInstance__c]
      + ', Items='
      + [SELECT COUNT() FROM CKR_ChecklistInstanceItem__c]
      + ', Shares='
      + [SELECT COUNT() FROM AccountShare WHERE RowCause = 'Manual']
      + ', SmokeUsers='
      + smokeUsersByPersona.size();
  }
}
