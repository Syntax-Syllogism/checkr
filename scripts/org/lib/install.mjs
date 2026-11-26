import { join } from "node:path";
import { setTimeout } from "node:timers/promises";
import { soqlLiteral } from "./apex.mjs";

export const CHECKR_PACKAGE = "checkr";
export const PERMISSION_SETS = [
  "CKR_Admin",
  "CKR_User",
  "CKR_ReadOnly",
  "CKR_GateBypass",
  "CKR_AuditMaintenance"
];
export const LWC_BUNDLES = [
  "ckrChecklistViewer",
  "ckrChecklistCreateAction",
  "ckrPublishTemplateVersion"
];
export const REFERENCE_SHIM = "sfdx-source/reference/main/triggers";

// Install scenarios prove the package on its own, so they refuse anything but
// a disposable scratch org and never touch the shared, source-deployed
// evidence org.
export function assertDisposableOrg(ctx, scenario) {
  if (
    ctx.org === "checkr-evidence" ||
    (ctx.env?.CKR_EVIDENCE_ORG && ctx.org === ctx.env.CKR_EVIDENCE_ORG)
  )
    throw new Error(`${scenario} must not use the shared evidence org`);
  if (!ctx.orgInfo?.scratch)
    throw new Error(`${scenario} requires a fresh scratch org`);
}

export async function installPackage(
  sfJson,
  packageId,
  { sleep = setTimeout, now = Date.now, timeoutMs = 30 * 60 * 1000 } = {}
) {
  if (!/^04t[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?$/.test(packageId))
    throw new Error("Expected a package version ID (04t)");
  const started = now();
  let result = sfJson([
    "package",
    "install",
    "--package",
    packageId,
    "--wait",
    "1",
    "--publish-wait",
    "10",
    "--security-type",
    "AdminsOnly",
    "--upgrade-type",
    "Mixed",
    "--no-prompt"
  ]).result;
  while (result?.Status !== "SUCCESS") {
    if (result?.Status === "ERROR" || !result?.Id)
      throw new Error(`Package install failed: ${JSON.stringify(result)}`);
    if (now() - started >= timeoutMs)
      throw new Error("Package install timed out");
    await sleep(1000);
    result = sfJson([
      "package",
      "install",
      "report",
      "--request-id",
      result.Id
    ]).result;
  }
  return { packageId, status: result.Status, elapsedMs: now() - started };
}

export function installedVersion(ctx) {
  const rows = ctx.sfJson(["package", "installed", "list"]).result ?? [];
  const row = rows.find((r) => r.SubscriberPackageName === CHECKR_PACKAGE);
  return row
    ? {
        packageId: row.SubscriberPackageVersionId,
        version: row.SubscriberPackageVersionNumber
      }
    : null;
}

export function checkInstalled(ctx, name, expected, file) {
  const installed = installedVersion(ctx);
  ctx.artifact(file, installed);
  ctx.check(
    name,
    installed?.packageId === expected,
    installed ? `${installed.version} ${installed.packageId}` : "not found"
  );
  return installed;
}

// The post-install step from docs/installation.md: a subscriber enables an
// object by deploying its own trigger shim. The reference Account shim stands
// in for it; the supported-object record for Account ships in the package.
export function deployReferenceShim(ctx) {
  return ctx.sfJson([
    "project",
    "deploy",
    "start",
    "--source-dir",
    join(ctx.root, REFERENCE_SHIM),
    "--wait",
    "20"
  ]).result;
}

const inList = (names) => names.map(soqlLiteral).join(", ");

export function packageMetadata(ctx) {
  const permissionSets = ctx
    .soql(
      `SELECT Name FROM PermissionSet WHERE Name IN (${inList(PERMISSION_SETS)})`
    )
    .map((row) => row.Name);
  const lwc = (
    ctx.sfJson([
      "data",
      "query",
      "--use-tooling-api",
      "--query",
      `SELECT DeveloperName FROM LightningComponentBundle WHERE DeveloperName IN (${inList(LWC_BUNDLES)})`
    ]).result?.records ?? []
  ).map((row) => row.DeveloperName);
  // Querying the type proves it exists; the Account row ships with the package.
  const supportedObjects = ctx
    .soql("SELECT DeveloperName FROM CKR_SupportedObject__mdt")
    .map((row) => row.DeveloperName);
  return { permissionSets, lwc, supportedObjects };
}

export function checkPackageMetadata(ctx, metadata) {
  const missing = (expected, found) =>
    expected.filter((name) => !found.includes(name));
  const permsets = missing(PERMISSION_SETS, metadata.permissionSets);
  ctx.check(
    "packaged permission sets exist",
    !permsets.length,
    permsets.length ? `missing ${permsets.join(", ")}` : ""
  );
  const lwc = missing(LWC_BUNDLES, metadata.lwc);
  ctx.check(
    "packaged LWCs exist",
    !lwc.length,
    lwc.length ? `missing ${lwc.join(", ")}` : ""
  );
  ctx.check(
    "CKR_SupportedObject__mdt ships the Account record",
    metadata.supportedObjects.includes("Account"),
    metadata.supportedObjects.join(", ")
  );
}

// Checklist rows owned by this run's fixture key, compared across an upgrade.
export function fixtureSnapshot(ctx) {
  const prefix = soqlLiteral(`${ctx.fixtureKey}%`);
  const template = `CKR_ChecklistTemplate__r.CKR_DeveloperName__c LIKE ${prefix}`;
  return {
    templates: ctx.soql(
      `SELECT Id, CKR_CurrentPublishedVersion__c FROM CKR_ChecklistTemplate__c WHERE CKR_DeveloperName__c LIKE ${prefix} ORDER BY Id`
    ),
    versions: ctx.soql(
      `SELECT Id, CKR_Status__c FROM CKR_ChecklistTemplateVersion__c WHERE ${template} ORDER BY Id`
    ),
    instances: ctx.soql(
      `SELECT Id, CKR_IsComplete__c FROM CKR_ChecklistInstance__c WHERE ${template} ORDER BY Id`
    ),
    items: ctx.soql(
      `SELECT Id, CKR_Completed__c FROM CKR_ChecklistInstanceItem__c WHERE CKR_ChecklistInstance__r.${template} ORDER BY Id`
    ),
    auditEvents: ctx.soql(
      `SELECT Id FROM CKR_ChecklistAuditEvent__c WHERE CKR_ChecklistInstance__r.${template} ORDER BY Id`
    )
  };
}

// Saves an Account as the non-admin worker; returns the gate error, if any.
export function workerSave(ctx, accountId, rating) {
  try {
    ctx.sfJson([
      "data",
      "update",
      "record",
      "--target-org",
      ctx.worker,
      "--sobject",
      "Account",
      "--record-id",
      accountId,
      "--values",
      `Rating=${rating}`
    ]);
    return null;
  } catch (error) {
    return error.message;
  }
}
