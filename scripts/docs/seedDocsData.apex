// Seeds the admin guide screenshot data as the running admin user.
//
// Dev tooling only, run by scripts/docs/capture-screenshots.mjs (or by hand
// with `sf apex run --file scripts/docs/seedDocsData.apex --target-org <alias>
// --json`). Unlike scripts/seedSmokeData.apex it needs no persona users, so it
// works in an org whose licenses are all in use. It never deletes anything:
// when the docs template already exists it does nothing.
//
// It creates the Account Onboarding template with a Published v1 (three items,
// two gate rules) and a Draft v2, three Accounts (one incomplete checklist,
// one complete checklist, one with none), item audit events through the viewer
// controller, and one audited bypass through a temporary user-level
// CKR_Settings__c row.
String developerName = 'Docs_Account_Onboarding';
if (
  ![
    SELECT Id
    FROM CKR_ChecklistTemplate__c
    WHERE CKR_DeveloperName__c = :developerName
  ]
    .isEmpty()
) {
  System.debug('Docs data already seeded; nothing to do.');
  return;
}

CKR_ChecklistTemplate__c template =
  new CKR_ChecklistTemplate__c(
    Name = 'Account Onboarding',
    CKR_DeveloperName__c = developerName,
    CKR_SupportedObjectDeveloperName__c = 'Account',
    CKR_TargetObjectApiName__c = 'Account',
    CKR_Description__c =
      'Steps to finish before an Account becomes a direct customer.',
    CKR_Active__c = true
  );
insert template;

CKR_ChecklistTemplateVersion__c v1 =
  new CKR_ChecklistTemplateVersion__c(
    CKR_ChecklistTemplate__c = template.Id,
    CKR_Status__c = 'Draft',
    CKR_VersionNumber__c = 1,
    CKR_CompletionAccessMode__c = 'EditAccess',
    CKR_Description__c = 'First onboarding version.'
  );
insert v1;

List<CKR_ChecklistTemplateItem__c> v1Items =
  new List<CKR_ChecklistTemplateItem__c>{
    new CKR_ChecklistTemplateItem__c(
      CKR_ChecklistTemplateVersion__c = v1.Id,
      CKR_Label__c = 'Confirm executive sponsor',
      CKR_HelpText__c = 'Name the sponsor and how they confirmed.',
      CKR_ExplanationInputType__c = 'Text',
      CKR_ExplanationRequired__c = true,
      CKR_Required__c = true,
      CKR_SortOrder__c = 1
    ),
    new CKR_ChecklistTemplateItem__c(
      CKR_ChecklistTemplateVersion__c = v1.Id,
      CKR_Label__c = 'Select billing profile',
      CKR_ExplanationInputType__c = 'Picklist',
      CKR_ExplanationPicklistValues__c =
        'Standard Billing;Enterprise Billing;Partner Billing',
      CKR_ExplanationRequired__c = true,
      CKR_Required__c = true,
      CKR_SortOrder__c = 2
    ),
    new CKR_ChecklistTemplateItem__c(
      CKR_ChecklistTemplateVersion__c = v1.Id,
      CKR_Label__c = 'Capture kickoff notes',
      CKR_ExplanationInputType__c = 'Text',
      CKR_Required__c = false,
      CKR_SortOrder__c = 3
    )
  };
insert v1Items;

insert new List<CKR_ChecklistGateRule__c>{
  new CKR_ChecklistGateRule__c(
    Name = 'Industry change gate',
    CKR_ChecklistTemplateVersion__c = v1.Id,
    CKR_ProtectedActionType__c = 'AnyFieldValueChange',
    CKR_TargetFieldApiName__c = 'Industry',
    CKR_ErrorMessage__c =
      'Complete the Account Onboarding checklist before changing Industry.',
    CKR_SortOrder__c = 10
  ),
  new CKR_ChecklistGateRule__c(
    Name = 'Direct customer gate',
    CKR_ChecklistTemplateVersion__c = v1.Id,
    CKR_ProtectedActionType__c = 'SpecificFieldValueChange',
    CKR_TargetFieldApiName__c = 'Type',
    CKR_TargetValueSet__c = 'Customer - Direct\nCustomer - Channel',
    CKR_ErrorMessage__c =
      'Complete the Account Onboarding checklist before making this Account a customer.',
    CKR_SortOrder__c = 20
  )
};

new CKR_DefaultTemplateVersionService().publish(v1.Id);

// v2 stays Draft so the guide can show the Publish Version action.
CKR_ChecklistTemplateVersion__c v2 =
  new CKR_ChecklistTemplateVersion__c(
    CKR_ChecklistTemplate__c = template.Id,
    CKR_Status__c = 'Draft',
    CKR_VersionNumber__c = 2,
    CKR_CompletionAccessMode__c = 'EditAccess',
    CKR_Description__c = 'Adds the data processing agreement step.'
  );
insert v2;
List<CKR_ChecklistTemplateItem__c> v2Items =
  new List<CKR_ChecklistTemplateItem__c>();
for (CKR_ChecklistTemplateItem__c item : v1Items) {
  CKR_ChecklistTemplateItem__c copy = item.clone(false, true, false, false);
  copy.CKR_ChecklistTemplateVersion__c = v2.Id;
  v2Items.add(copy);
}
v2Items.add(
  new CKR_ChecklistTemplateItem__c(
    CKR_ChecklistTemplateVersion__c = v2.Id,
    CKR_Label__c = 'Confirm data processing agreement',
    CKR_ExplanationInputType__c = 'Text',
    CKR_Required__c = true,
    CKR_SortOrder__c = 4
  )
);
insert v2Items;
insert new List<CKR_ChecklistGateRule__c>{
  new CKR_ChecklistGateRule__c(
    Name = 'Industry change gate',
    CKR_ChecklistTemplateVersion__c = v2.Id,
    CKR_ProtectedActionType__c = 'AnyFieldValueChange',
    CKR_TargetFieldApiName__c = 'Industry',
    CKR_ErrorMessage__c =
      'Complete the Account Onboarding checklist before changing Industry.',
    CKR_SortOrder__c = 10
  )
};

List<Account> accounts =
  new List<Account>{
    new Account(
      Name = 'Redwood Health',
      Industry = 'Healthcare',
      Type = 'Prospect'
    ),
    new Account(
      Name = 'Bluebird Logistics',
      Industry = 'Transportation',
      Type = 'Prospect'
    ),
    new Account(
      Name = 'Northstar Retail',
      Industry = 'Retail',
      Type = 'Prospect'
    )
  };
insert accounts;

Map<Id, Id> instanceIdByAccountId = new Map<Id, Id>();
for (Account account : new List<Account>{ accounts[0], accounts[1] }) {
  CKR_ChecklistInstanceCreateRequest request =
    new CKR_ChecklistInstanceCreateRequest();
  request.templateVersionId = v1.Id;
  request.parentRecordId = account.Id;
  request.parentObjectApiName = 'Account';
  request.dueDate = Date.today().addDays(14);
  CKR_ChecklistInstanceCreateResult result =
    new CKR_DefaultChecklistInstanceService().createFromTemplate(request);
  if (result == null || result.success != true) {
    throw new IllegalArgumentException(
      'Failed to create a checklist: '
      + (result == null ? 'unknown' : String.join(result.messages, ' | '))
    );
  }
  instanceIdByAccountId.put(account.Id, result.checklistInstanceId);
}

Map<String, String> redwoodAnswers =
  new Map<String, String>{
    'Confirm executive sponsor' => 'Dana Lee, VP Operations, confirmed on the kickoff call.'
  };
Map<String, String> bluebirdAnswers =
  new Map<String, String>{
    'Confirm executive sponsor' => 'Sam Ortiz, COO, confirmed by email.',
    'Select billing profile' => 'Enterprise Billing',
    'Capture kickoff notes' => 'Go-live planned for next quarter.'
  };
Map<Id, Map<String, String>> answersByInstanceId =
  new Map<Id, Map<String, String>>{
    instanceIdByAccountId.get(accounts[0].Id) => redwoodAnswers,
    instanceIdByAccountId.get(accounts[1].Id) => bluebirdAnswers
  };
for (CKR_ChecklistInstanceItem__c item : [
  SELECT Id, CKR_ChecklistInstance__c, CKR_Label__c
  FROM CKR_ChecklistInstanceItem__c
  WHERE CKR_ChecklistInstance__c IN :answersByInstanceId.keySet()
]) {
  String answer =
    answersByInstanceId.get(item.CKR_ChecklistInstance__c)
      .get(item.CKR_Label__c);
  if (answer != null) {
    CKR_ChecklistItemUpdateRequest request =
      new CKR_ChecklistItemUpdateRequest();
    request.checklistItemId = item.Id;
    request.checkboxValue = true;
    request.explanation = answer;
    CKR_ChecklistViewerController.updateChecklistItem(request);
  }
}

// One audited bypass: a temporary user-level switch, removed in the same
// transaction. Redwood's checklist is incomplete, so the gate would block.
CKR_Settings__c bypass =
  new CKR_Settings__c(
    SetupOwnerId = UserInfo.getUserId(),
    CKR_BypassGate__c = true
  );
insert bypass;
update new Account(Id = accounts[0].Id, Industry = 'Biotechnology');
delete bypass;

System.debug('Docs data seeded.');
