// Admin-guide walkthrough (116) against an org with the Checkr beta installed.
// Follows chapters 2-11 with the records, fields and entry points the guide
// names, and records each step's outcome.
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";

const ORG = process.argv[2];
const OUT = process.argv[3];
const KEY = "WT" + Date.now().toString(36);
const steps = [];

function sf(args) {
  let out;
  try {
    out = execFileSync("sf", [...args, "--target-org", ORG, "--json"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      maxBuffer: 64 * 1024 * 1024
    });
  } catch (e) {
    out = e.stdout;
  }
  const json = JSON.parse(out);
  if (json.status !== 0) {
    const err = new Error(json.message ?? JSON.stringify(json));
    err.json = json;
    throw err;
  }
  return json.result;
}
const soql = (q) => sf(["data", "query", "--query", q]).records;
const tooling = (q) =>
  sf(["data", "query", "--use-tooling-api", "--query", q]).records;
const create = (sobject, values) =>
  sf(["data", "create", "record", "--sobject", sobject, "--values", values]).id;
function update(sobject, id, values) {
  try {
    sf(["data", "update", "record", "--sobject", sobject, "--record-id", id, "--values", values]);
    return null;
  } catch (e) {
    return e.message;
  }
}
function apex(code) {
  const file = `${OUT}/anon.apex`;
  writeFileSync(file, code);
  const r = sf(["apex", "run", "--file", file]);
  if (!r.success)
    throw new Error(r.compileProblem || r.exceptionMessage || "apex failed");
  return r;
}
function apexError(code) {
  try {
    apex(code);
    return null;
  } catch (e) {
    return e.message;
  }
}
function step(chapter, name, ok, detail = "") {
  steps.push({ chapter, name, outcome: ok ? "passed" : "failed", detail });
  console.log(`${ok ? "PASS" : "FAIL"} [${chapter}] ${name}${detail ? " — " + detail : ""}`);
}
const q = (s) => `'${String(s).replace(/'/g, "\\'")}'`;

// Chapter 2: install and permission sets
const pkgs = sf(["package", "installed", "list"]);
const pkg = pkgs.find((p) => p.SubscriberPackageName === "checkr");
step("02", "checkr package installed", Boolean(pkg), pkg ? `${pkg.SubscriberPackageVersionNumber} ${pkg.SubscriberPackageVersionId}` : "");
const app = soql("SELECT Name, Label FROM AppMenuItem WHERE Label = 'CheckR'");
step("02", "CheckR app in the App Launcher", app.length > 0, app.map((a) => a.Label).join(", "));
const tabs = soql("SELECT Name FROM TabDefinition WHERE Name IN ('CKR_ChecklistTemplate__c','CKR_ChecklistInstance__c')");
step("02", "Checklist Templates and Checklist Instances tabs", tabs.length === 2, tabs.map((t) => t.Name).join(", "));
const auditTab = soql("SELECT Name FROM TabDefinition WHERE Name IN ('CKR_ChecklistAuditEvent__c','CKR_GateBypassEvent__c')");
step("02", "audit and bypass history have no tab", auditTab.length === 0);
const permsets = soql("SELECT Name FROM PermissionSet WHERE Name LIKE 'CKR_%' ORDER BY Name").map((p) => p.Name);
const expected = ["CKR_Admin", "CKR_AuditMaintenance", "CKR_GateBypass", "CKR_ReadOnly", "CKR_User"];
step("02", "five permission sets in the table", expected.every((n) => permsets.includes(n)), permsets.join(", "));
const adminBypass = soql("SELECT Id FROM SetupEntityAccess WHERE Parent.Name = 'CKR_Admin' AND SetupEntityType = 'CustomPermission' AND SetupEntityId IN (SELECT Id FROM CustomPermission WHERE DeveloperName LIKE '%Bypass%')");
step("02", "CKR_Admin does not include bypass", adminBypass.length === 0);
const profileGrants = soql("SELECT Parent.Profile.Name, SetupEntityId FROM SetupEntityAccess WHERE Parent.IsOwnedByProfile = true AND SetupEntityId IN (SELECT Id FROM CustomPermission WHERE DeveloperName IN ('CKR_BypassGate','CKR_Audit_Maintenance'))");
step("02", "after the post-install step no profile holds Checkr bypass or audit maintenance", profileGrants.length === 0, profileGrants.map((g) => g.Parent.Profile?.Name).join(", "));
const lwc = tooling("SELECT DeveloperName FROM LightningComponentBundle WHERE DeveloperName IN ('ckrChecklistViewer','ckrChecklistCreateAction')");
step("02", "ckrChecklistViewer and ckrChecklistCreateAction ship", lwc.length === 2);
const actions = tooling("SELECT DeveloperName, SobjectType FROM QuickActionDefinition WHERE DeveloperName IN ('CKR_New_Checklist','CKR_PublishVersion')");
step("02", "New Checklist and Publish Version quick actions ship", actions.length === 2, actions.map((a) => `${a.SobjectType}.${a.DeveloperName}`).join(", "));
const page = tooling("SELECT DeveloperName FROM FlexiPage WHERE DeveloperName = 'CKR_Example_Account_Record_Page'");
step("02", "CheckR app ships an Account record page", page.length === 1);

// Chapter 3: enabling an object
const so = soql("SELECT DeveloperName, CKR_ObjectApiName__c, CKR_Active__c, CKR_SupportsGates__c FROM CKR_SupportedObject__mdt WHERE DeveloperName = 'Account'");
step("03", "shipped Account supported-object record is active and supports gates", so.length === 1 && so[0].CKR_Active__c && so[0].CKR_SupportsGates__c && so[0].CKR_ObjectApiName__c === "Account");
const shim = tooling("SELECT Name, TableEnumOrId FROM ApexTrigger WHERE Name = 'CKR_AccountTrigger'");
step("03", "Account trigger shim deployed (developer step)", shim.length === 1);

// Retire templates left by earlier walkthrough runs. Unchecking Active only hides
// a template from New Checklist; its Published rules keep gating. Publishing a
// version with no rules is what stops it gating records without a checklist.
for (const t of soql("SELECT Id, CKR_CurrentPublishedVersion__c, (SELECT CKR_VersionNumber__c FROM ChecklistTemplateVersions__r ORDER BY CKR_VersionNumber__c DESC LIMIT 1) FROM CKR_ChecklistTemplate__c WHERE CKR_DeveloperName__c LIKE 'WT%'"))
{
  const current = t.CKR_CurrentPublishedVersion__c;
  const liveRules = current ? soql(`SELECT Id FROM CKR_ChecklistGateRule__c WHERE CKR_Active__c = true AND CKR_ChecklistTemplateVersion__c = '${current}'`) : [];
  if (!liveRules.length) continue;
  const next = (t.ChecklistTemplateVersions__r?.records?.[0]?.CKR_VersionNumber__c ?? 0) + 1;
  const vr = create("CKR_ChecklistTemplateVersion__c", `CKR_ChecklistTemplate__c=${t.Id} CKR_VersionNumber__c=${next} CKR_Status__c=Draft CKR_CompletionAccessMode__c=EditAccess CKR_Description__c=${q("Retire: no rules")}`);
  create("CKR_ChecklistTemplateItem__c", `CKR_ChecklistTemplateVersion__c=${vr} CKR_Label__c=${q("Retired")} CKR_SortOrder__c=1 CKR_Required__c=false CKR_Active__c=true`);
  apex(`CKR_TemplateVersionPublishController.publishVersion('${vr}');`);
}

// Chapter 4: author a template (field table)
const templateId = create("CKR_ChecklistTemplate__c", `Name=${q(KEY + " Account Onboarding")} CKR_DeveloperName__c=${KEY}_Account_Onboarding CKR_SupportedObjectDeveloperName__c=Account CKR_TargetObjectApiName__c=Account CKR_Active__c=true CKR_Description__c=${q("Walkthrough")}`);
step("04", "create the template with the chapter 4 fields", Boolean(templateId), templateId);
const v1 = create("CKR_ChecklistTemplateVersion__c", `CKR_ChecklistTemplate__c=${templateId} CKR_VersionNumber__c=1 CKR_Status__c=Draft CKR_CompletionAccessMode__c=EditAccess CKR_Description__c=${q("First version")}`);
step("04", "create Draft v1 with EditAccess", Boolean(v1), v1);
const statusErr = update("CKR_ChecklistTemplateVersion__c", v1, "CKR_Status__c=Published");
step("04", "setting Status to Published directly is rejected", Boolean(statusErr), statusErr ?? "accepted");
const emptyPublish = apexError(`CKR_TemplateVersionPublishController.publishVersion('${v1}');`);
step("06", "publishing a version with no items is rejected", Boolean(emptyPublish), emptyPublish ?? "published");
const item1 = create("CKR_ChecklistTemplateItem__c", `CKR_ChecklistTemplateVersion__c=${v1} CKR_Label__c=${q("Confirm executive sponsor")} CKR_SortOrder__c=1 CKR_Required__c=true CKR_Active__c=true CKR_HelpText__c=${q("Name the sponsor")}`);
const item2 = create("CKR_ChecklistTemplateItem__c", `CKR_ChecklistTemplateVersion__c=${v1} CKR_Label__c=${q("Pick a segment")} CKR_SortOrder__c=2 CKR_Required__c=true CKR_Active__c=true CKR_ExplanationRequired__c=true CKR_ExplanationInputType__c=Picklist CKR_ExplanationPicklistValues__c=${q("SMB;Mid-Market;Enterprise")}`);
const item3 = create("CKR_ChecklistTemplateItem__c", `CKR_ChecklistTemplateVersion__c=${v1} CKR_Label__c=${q("Optional intro call")} CKR_SortOrder__c=3 CKR_Required__c=false CKR_Active__c=true`);
step("04", "add required, picklist-explanation and optional items", Boolean(item1 && item2 && item3));

// Chapter 5: gate rule
const msg1 = `Complete the ${KEY} Account Onboarding checklist before changing Industry.`;
const rule1 = create("CKR_ChecklistGateRule__c", `Name=${q("Industry change gate")} CKR_ChecklistTemplateVersion__c=${v1} CKR_TargetFieldApiName__c=Industry CKR_ProtectedActionType__c=AnyFieldValueChange CKR_ErrorMessage__c=${q(msg1)} CKR_SortOrder__c=1 CKR_Active__c=true`);
step("05", "add an AnyFieldValueChange gate rule on Industry", Boolean(rule1), rule1);

// Accounts: A (will complete v1), B (no checklist), C (incomplete v1)
const acct = (n) => create("Account", `Name=${q(`${KEY}-${n}`)} Industry=Banking`);
const A = acct("A"), B = acct("B"), C = acct("C");
step("05", "inserts are not gated (D3)", Boolean(A && B && C));
const draftChange = update("Account", B, "Industry=Energy");
step("05", "Draft version does not gate a record with no checklist", !draftChange, draftChange ?? "");

// Chapter 6: publish v1
apex(`CKR_TemplateVersionPublishController.publishVersion('${v1}');`);
const [v1row] = soql(`SELECT CKR_Status__c, CKR_PublishedBy__c, CKR_PublishedOn__c, CKR_ChecklistTemplate__r.CKR_CurrentPublishedVersion__c FROM CKR_ChecklistTemplateVersion__c WHERE Id='${v1}'`);
step("06", "Publish Version: v1 Published with publisher, timestamp and template pointer", v1row.CKR_Status__c === "Published" && v1row.CKR_PublishedBy__c && v1row.CKR_PublishedOn__c && v1row.CKR_ChecklistTemplate__r.CKR_CurrentPublishedVersion__c === v1);
const republish = apexError(`CKR_TemplateVersionPublishController.publishVersion('${v1}');`);
step("06", "publishing an already published version is rejected", Boolean(republish), republish ?? "");
const frozenItem = update("CKR_ChecklistTemplateItem__c", item1, `CKR_Label__c=${q("Edited")}`);
step("06", "items on a Published version cannot be edited", Boolean(frozenItem), frozenItem ?? "edited");
const frozenRule = update("CKR_ChecklistGateRule__c", rule1, "CKR_Active__c=false");
step("06", "rules on a Published version cannot be edited", Boolean(frozenRule), frozenRule ?? "edited");

// Chapter 3 "check that it worked" + chapter 7 blocked save
const blocked = update("Account", B, "Industry=Retail");
step("03", "a record with no checklist is blocked with the rule's message", Boolean(blocked?.includes(msg1)), blocked ?? "saved");

// Chapter 7: attach and work checklists (create action and viewer controllers)
const ctx = apex(`System.debug(JSON.serialize(CKR_ChecklistCreateActionController.getCreateContext('${A}', 'Account')));`);
const offered = (ctx.logs ?? "").includes(templateId);
step("07", "New Checklist offers the Published template", offered);
const createFor = (rec) => apex(`CKR_ChecklistInstanceCreateResult r = CKR_ChecklistCreateActionController.createChecklistAction('${templateId}', null, '${rec}', 'Account', Date.today().addDays(7)); if (r.success != true) throw new IllegalArgumentException(String.join(r.messages, '; '));`);
createFor(A);
createFor(C);
const dup = apexError(`CKR_ChecklistInstanceCreateResult r = CKR_ChecklistCreateActionController.createChecklistAction('${templateId}', null, '${A}', 'Account', null); if (r.success != true) throw new IllegalArgumentException(String.join(r.messages, '; '));`);
step("07", "a second checklist from the same template on one record fails", Boolean(dup), dup ?? "created");
const itemsOf = (rec) => soql(`SELECT Id, CKR_Label__c, CKR_Required__c FROM CKR_ChecklistInstanceItem__c WHERE CKR_ChecklistInstance__r.CKR_ParentRecordId__c='${rec}' ORDER BY CKR_SortOrder__c`);
const aItems = itemsOf(A);
step("07", "checklist copies the three active template items", aItems.length === 3);
const tick = (id, explanation) => apex(`CKR_ChecklistViewerController.updateChecklistItem('${id}', true, ${explanation ? q(explanation) : "null"}, null, null, null, null, null);`);
tick(aItems[0].Id);
const noExplanation = (() => { try { tick(aItems[1].Id); return null; } catch (e) { return e.message; } })();
const [afterNoExp] = soql(`SELECT CKR_IsComplete__c FROM CKR_ChecklistInstance__c WHERE CKR_ParentRecordId__c='${A}'`);
step("07", "an explanation-required item does not count without an explanation", Boolean(noExplanation) || !afterNoExp.CKR_IsComplete__c, noExplanation ?? "not complete");
tick(aItems[1].Id, "Enterprise");
const [aInst] = soql(`SELECT CKR_IsComplete__c, CKR_PercentComplete__c FROM CKR_ChecklistInstance__c WHERE CKR_ParentRecordId__c='${A}'`);
step("07", "required items done: checklist complete without the optional item", aInst.CKR_IsComplete__c === true, `percent ${aInst.CKR_PercentComplete__c}`);
const aSave = update("Account", A, "Industry=Retail");
step("07", "complete checklist lets the gated save through", !aSave, aSave ?? "");
const audit = soql(`SELECT CKR_EventType__c FROM CKR_ChecklistAuditEvent__c WHERE CKR_ChecklistInstance__r.CKR_ParentRecordId__c='${A}'`);
step("07", "every change is recorded in the audit history", audit.length >= 2, [...new Set(audit.map((a) => a.CKR_EventType__c))].join(", "));

// Chapter 6: publish v2
const msg2 = `Complete the ${KEY} Account Onboarding checklist before making the Account a customer.`;
const v2 = create("CKR_ChecklistTemplateVersion__c", `CKR_ChecklistTemplate__c=${templateId} CKR_VersionNumber__c=2 CKR_Status__c=Draft CKR_CompletionAccessMode__c=EditAccess CKR_Description__c=${q("Gate customer type")}`);
create("CKR_ChecklistTemplateItem__c", `CKR_ChecklistTemplateVersion__c=${v2} CKR_Label__c=${q("Confirm executive sponsor")} CKR_SortOrder__c=1 CKR_Required__c=true CKR_Active__c=true`);
create("CKR_ChecklistGateRule__c", `Name=${q("Customer type gate")} CKR_ChecklistTemplateVersion__c=${v2} CKR_TargetFieldApiName__c=Type CKR_ProtectedActionType__c=SpecificFieldValueChange CKR_TargetValueSet__c=${q("Customer - Direct;Customer - Channel")} CKR_ErrorMessage__c=${q(msg2)} CKR_SortOrder__c=1 CKR_Active__c=true`);
apex(`CKR_TemplateVersionPublishController.publishVersion('${v2}');`);
const vers = soql(`SELECT Id, CKR_Status__c, CKR_PublishedOn__c FROM CKR_ChecklistTemplateVersion__c WHERE CKR_ChecklistTemplate__c='${templateId}' ORDER BY CKR_VersionNumber__c`);
step("06", "publishing v2 makes v1 Historical; both keep Published On", vers[0].CKR_Status__c === "Historical" && vers[1].CKR_Status__c === "Published" && vers.every((v) => v.CKR_PublishedOn__c), vers.map((v) => v.CKR_Status__c).join(" → "));
const insts = soql(`SELECT CKR_ChecklistTemplateVersion__c FROM CKR_ChecklistInstance__c WHERE CKR_ChecklistTemplate__c='${templateId}'`);
step("06", "existing checklists still point at v1", insts.every((i) => i.CKR_ChecklistTemplateVersion__c === v1));
const aType = update("Account", A, "Type='Customer - Direct'");
step("06", "v1 complete: v2's rules do not apply", !aType, aType ?? "");
const cInd = update("Account", C, "Industry=Energy");
step("06", "v1 incomplete: still judged by v1's rules though v1 is Historical", Boolean(cInd?.includes(msg1)), cInd ?? "saved");
const bInd = update("Account", B, "Industry=Energy");
step("06", "no checklist: v1's (Historical) rules no longer apply", !bInd, bInd ?? "");
const bType = update("Account", B, "Type='Customer - Channel'");
step("06", "no checklist: judged by v2's rules", Boolean(bType?.includes(msg2)), bType ?? "saved");
const bAway = update("Account", B, "Type=Prospect");
step("05", "a change to a value outside the target set is not gated", !bAway, bAway ?? "");
const ctx2 = apex(`System.debug(JSON.serialize(CKR_ChecklistCreateActionController.getCreateContext('${B}', 'Account')));`);
step("06", "new checklists from New Checklist use v2", (ctx2.logs ?? "").includes(v2));

// Chapter 11 / runbook: investigate the blocked save on B
const rules = soql(`SELECT Id, Name, CKR_TargetFieldApiName__c, CKR_ErrorMessage__c, CKR_ChecklistTemplateVersion__r.CKR_VersionNumber__c, CKR_ChecklistTemplateVersion__r.CKR_Status__c FROM CKR_ChecklistGateRule__c WHERE CKR_Active__c = TRUE AND CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__r.CKR_TargetObjectApiName__c = 'Account' ORDER BY CKR_SortOrder__c`);
const found = rules.find((r) => r.CKR_ErrorMessage__c === msg2);
step("11", "runbook step 1 query finds the rule from its error text", Boolean(found) && found.CKR_ChecklistTemplateVersion__r.CKR_Status__c === "Published");
const triage = soql(`SELECT Id, CKR_IsComplete__c FROM CKR_ChecklistInstance__c WHERE CKR_ParentRecordId__c = '${B}'`);
step("11", "runbook step 2 triage: no checklist, rule on Published version → fix A", triage.length === 0);

// Chapter 8: bypass, option 1 (permission set) then option 2 (setting)
const me = sf(["org", "display"]).username;
const [user] = soql(`SELECT Id FROM User WHERE Username=${q(me)}`);
sf(["org", "assign", "permset", "--name", "CKR_GateBypass"]);
const bypass1 = update("Account", B, "Type='Customer - Direct'");
const ev1 = soql(`SELECT CKR_Source__c, CKR_GateRule__r.Name, CKR_Details__c FROM CKR_GateBypassEvent__c WHERE CKR_RecordId__c='${B}'`);
step("08", "option 1: CKR_GateBypass lets the save through", !bypass1, bypass1 ?? "");
step("08", "option 1: bypassed save recorded with source and first blocking rule", ev1.length === 1 && ev1[0].CKR_Source__c === "CustomPermission" && ev1[0].CKR_GateRule__r?.Name === "Customer type gate", JSON.stringify(ev1[0] ?? {}));
const [psa] = soql(`SELECT Id FROM PermissionSetAssignment WHERE AssigneeId='${user.Id}' AND PermissionSet.Name='CKR_GateBypass'`);
sf(["data", "delete", "record", "--sobject", "PermissionSetAssignment", "--record-id", psa.Id]);
update("Account", B, "Type=Prospect");
const reblocked = update("Account", B, "Type='Customer - Direct'");
step("08", "removing the assignment restores the gate", Boolean(reblocked?.includes(msg2)), reblocked ?? "saved");
const settingId = create("CKR_Settings__c", `SetupOwnerId=${user.Id} CKR_BypassGate__c=true`);
const bypass2 = update("Account", B, "Type='Customer - Channel'");
const ev2 = soql(`SELECT CKR_Source__c FROM CKR_GateBypassEvent__c WHERE CKR_RecordId__c='${B}' ORDER BY CKR_OccurredOn__c DESC, Id DESC`);
step("08", "option 2: a user Checkr Settings row with Bypass Gate lets the save through and is audited", !bypass2 && ev2.length === 2 && ev2.some((e) => e.CKR_Source__c !== "CustomPermission"), ev2.map((e) => e.CKR_Source__c).join(", "));
sf(["data", "delete", "record", "--sobject", "CKR_Settings__c", "--record-id", settingId]);
update("Account", B, "Type=Prospect");
const reblocked2 = update("Account", B, "Type='Customer - Direct'");
step("08", "deleting the row restores the gate", Boolean(reblocked2?.includes(msg2)), reblocked2 ?? "saved");

// Chapter 9/11: append-only
const auditRow = soql(`SELECT Id FROM CKR_ChecklistAuditEvent__c WHERE CKR_ChecklistInstance__r.CKR_ParentRecordId__c='${A}' LIMIT 1`)[0];
const auditEdit = update("CKR_ChecklistAuditEvent__c", auditRow.Id, `CKR_Details__c=${q("tampered")}`);
step("09", "audit history is append-only for CKR_Admin", Boolean(auditEdit), auditEdit ?? "edited");
let delTpl = null;
try { sf(["data", "delete", "record", "--sobject", "CKR_ChecklistTemplate__c", "--record-id", templateId]); } catch (e) { delTpl = e.message; }
step("11", "a template with audit or bypass history cannot be deleted", Boolean(delTpl), delTpl ?? "deleted");

writeFileSync(`${OUT}/walkthrough.json`, JSON.stringify({ org: ORG, key: KEY, package: pkg, steps }, null, 2));
const failed = steps.filter((s) => s.outcome === "failed");
console.log(`${steps.length - failed.length}/${steps.length} passed`);
process.exit(failed.length ? 1 : 0);
