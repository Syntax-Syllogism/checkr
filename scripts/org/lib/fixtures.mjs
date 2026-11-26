import { randomUUID } from "node:crypto";
import { soqlLiteral } from "./apex.mjs";

export function readMetrics(result) {
  const line = result.logs
    ?.split("\n")
    .find((line) => line.includes("|DEBUG|CKR_EVIDENCE="));
  if (!line) throw new Error("CKR_EVIDENCE JSON was not found in the Apex log");
  return JSON.parse(line.slice(line.indexOf("CKR_EVIDENCE=") + 13));
}

// Fixtures are intentionally system-mode test data, scoped to this invocation.
export function seed(ctx, { count = 1, rules = 1, ownerId } = {}) {
  ctx.fixtureKey = `CKREvidence${randomUUID().replaceAll("-", "")}`;
  const key = soqlLiteral(ctx.fixtureKey);
  ctx.runAnonymous(`
    String key = ${key};
    List<Account> accounts = new List<Account>();
    for (Integer i=0; i<${count}; i++) accounts.add(new Account(
      Name=key+'-'+i, Rating='Cold'${ownerId ? `, OwnerId=${soqlLiteral(ownerId)}` : ""}));
    insert accounts;
    for (Integer i=0; i<${rules}; i++) {
      CKR_ChecklistTemplate__c template = new CKR_ChecklistTemplate__c(
        Name=key+'-'+i, CKR_DeveloperName__c=key+'_'+i,
        CKR_TargetObjectApiName__c='Account', CKR_SupportedObjectDeveloperName__c='Account', CKR_Active__c=true);
      insert template;
      CKR_ChecklistTemplateVersion__c version = new CKR_ChecklistTemplateVersion__c(
        CKR_ChecklistTemplate__c=template.Id, CKR_Status__c='Draft',
        CKR_VersionNumber__c=1, CKR_CompletionAccessMode__c='EditAccess');
      insert version;
      insert new CKR_ChecklistTemplateItem__c(CKR_ChecklistTemplateVersion__c=version.Id,
        CKR_Label__c='Evidence required item', CKR_Required__c=true, CKR_ExplanationInputType__c='Text', CKR_SortOrder__c=1);
      insert new CKR_ChecklistGateRule__c(CKR_ChecklistTemplateVersion__c=version.Id,
        CKR_Active__c=true, CKR_ProtectedActionType__c='SpecificFieldValueChange',
        CKR_TargetFieldApiName__c='Rating', CKR_TargetValue__c='Hot',
        CKR_ErrorMessage__c=key+' requires completion', CKR_SortOrder__c=i);
      ((CKR_IChecklistTemplateVersionService)CKR_AppFactory.getInstance(CKR_IChecklistTemplateVersionService.class)).publish(version.Id);
      if (${count} == 200) {
        List<CKR_ChecklistInstance__c> complete = new List<CKR_ChecklistInstance__c>();
        for (Integer j=0; j<100; j++) complete.add(new CKR_ChecklistInstance__c(
          CKR_ChecklistTemplate__c=template.Id, CKR_ChecklistTemplateVersion__c=version.Id,
          CKR_ParentObjectApiName__c='Account', CKR_ParentRecordId__c=String.valueOf(accounts[j].Id),
          CKR_UniqueKey__c=accounts[j].Id+'|'+template.Id, CKR_IsComplete__c=true));
        insert complete;
      }
    }
  `);
}

export function cleanup(ctx) {
  if (!ctx.fixtureKey) return;
  // Never use the smoke seeder's org-wide reset; touch only this run's fixtures.
  withAuditMaintenance(ctx, () =>
    ctx.runAnonymous(`
    String prefix=${soqlLiteral(ctx.fixtureKey + "%")};
    List<CKR_ChecklistTemplate__c> templates=[SELECT Id, CKR_CurrentPublishedVersion__c FROM CKR_ChecklistTemplate__c WHERE CKR_DeveloperName__c LIKE :prefix];
    Set<Id> ids=new Map<Id, CKR_ChecklistTemplate__c>(templates).keySet();
    delete [SELECT Id FROM CKR_ChecklistAuditEvent__c WHERE CKR_ChecklistInstance__r.CKR_ChecklistTemplate__c IN :ids];
    delete [SELECT Id FROM CKR_ChecklistInstance__c WHERE CKR_ChecklistTemplate__c IN :ids];
    for (CKR_ChecklistTemplate__c template:templates) template.CKR_CurrentPublishedVersion__c=null;
    update templates;
    // Master-detail cascade is reserved for removing this isolated fixture graph.
    delete templates;
    delete [SELECT Id FROM Account WHERE Name LIKE :prefix];
  `)
  );
}

export const noOp = async () => {};

// Scope elevated cleanup privileges to the operation and preserve prior grants.
export function withAuditMaintenance(ctx, action, username) {
  username ??= ctx.sfJson(["org", "display"]).result.username;
  const query = `SELECT Id FROM PermissionSetAssignment WHERE Assignee.Username=${soqlLiteral(username)} AND PermissionSet.Name='CKR_AuditMaintenance'`;
  const held = ctx.soql(query).length > 0;
  try {
    if (!held)
      ctx.sfJson([
        "org",
        "assign",
        "permset",
        "--name",
        "CKR_AuditMaintenance",
        "--on-behalf-of",
        username
      ]);
    return action();
  } finally {
    if (!held)
      for (const row of ctx.soql(query))
        ctx.sfJson([
          "data",
          "delete",
          "record",
          "--sobject",
          "PermissionSetAssignment",
          "--record-id",
          row.Id
        ]);
  }
}
