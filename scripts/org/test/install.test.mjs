import test from "node:test";
import assert from "node:assert/strict";
import { loadScenarios } from "../harness.mjs";
import {
  LWC_BUNDLES,
  PERMISSION_SETS,
  assertDisposableOrg,
  checkPackageMetadata,
  installedVersion
} from "../lib/install.mjs";
import smoke from "../scenarios/install-smoke.mjs";
import upgrade from "../scenarios/install-upgrade.mjs";

const OLD = "04t000000000001AAA";
const NEW = "04t000000000002AAA";

// A fake org: records every sf call and answers the queries the scenarios run.
function fakeOrg({ installed = OLD, permissionSets = PERMISSION_SETS } = {}) {
  const ctx = {
    org: "scratch",
    env: {},
    root: "/repo",
    orgInfo: { scratch: true },
    users: new Map([["worker", "worker@example.test"]]),
    worker: "worker@example.test",
    fixtureKey: "fixture",
    packageId: NEW,
    upgradeFrom: OLD,
    calls: [],
    anonymous: [],
    checks: [],
    metrics: {},
    artifacts: {},
    installed,
    version: null,
    packageVersion(version) {
      this.version = version;
    },
    check(name, passed, detail) {
      this.checks.push({ name, passed, detail });
    },
    metric(name, value) {
      this.metrics[name] = value;
    },
    artifact(name, value) {
      this.artifacts[name] = value;
    },
    soql(query) {
      if (query.includes("FROM PermissionSet "))
        return permissionSets.map((Name) => ({ Name }));
      if (query.includes("CKR_SupportedObject__mdt"))
        return [{ DeveloperName: "Account" }];
      if (query.includes("SELECT Rating")) return [{ Rating: "Hot" }];
      if (query.includes("FROM CKR_")) return [{ Id: "a00" }];
      return [{ Id: "001000000000001AAA" }];
    },
    runAnonymous(source) {
      this.anonymous.push(source);
      if (/updateChecklistItem/.test(source)) this.complete = true;
    },
    sfJson(args) {
      ctx.calls.push(args);
      const command = args.slice(0, 3).join(" ");
      if (args[0] === "package" && args[1] === "install") {
        ctx.installed = args[args.indexOf("--package") + 1];
        return { result: { Status: "SUCCESS" } };
      }
      if (command === "package installed list")
        return {
          result: [
            {
              SubscriberPackageName: "checkr",
              SubscriberPackageVersionId: ctx.installed,
              SubscriberPackageVersionNumber:
                ctx.installed === OLD ? "0.1.0.1" : "0.1.0.2"
            }
          ]
        };
      if (command === "org display")
        return { result: { username: "admin@example.test" } };
      if (args.includes("--use-tooling-api"))
        return {
          result: {
            records: LWC_BUNDLES.map((DeveloperName) => ({ DeveloperName }))
          }
        };
      if (command === "data update record") {
        const rating = args[args.indexOf("--values") + 1];
        const record = args[args.indexOf("--record-id") + 1];
        if (rating === "Rating=Hot" && (!ctx.complete || record === "fresh"))
          throw new Error(`${ctx.fixtureKey} requires completion`);
        return { result: {} };
      }
      return { result: {} };
    }
  };
  return ctx;
}

test("install scenario contracts load with descriptions and a deploy step", async () => {
  const scenarios = await loadScenarios(["install-smoke", "install-upgrade"]);
  assert.ok(scenarios.every((s) => s.description && s.deploy && s.cleanup));
});

test("install scenarios refuse the shared evidence org and non-scratch orgs", async () => {
  const base = { env: {}, orgInfo: { scratch: true } };
  assert.throws(
    () => assertDisposableOrg({ ...base, org: "checkr-evidence" }, "x"),
    /shared evidence org/
  );
  assert.throws(
    () =>
      assertDisposableOrg(
        { ...base, org: "mine", env: { CKR_EVIDENCE_ORG: "mine" } },
        "x"
      ),
    /shared evidence org/
  );
  assert.throws(
    () => assertDisposableOrg({ ...base, org: "dev", orgInfo: {} }, "x"),
    /fresh scratch org/
  );
  for (const scenario of [smoke, upgrade]) {
    const ctx = fakeOrg();
    ctx.orgInfo = { scratch: false };
    await assert.rejects(scenario.deploy(ctx), /fresh scratch org/);
    assert.equal(ctx.calls.length, 0);
    const missing = fakeOrg();
    missing.packageId = undefined;
    await assert.rejects(scenario.deploy(missing), /requires --package/);
  }
});

test("installed version reads only the checkr package", () => {
  const ctx = fakeOrg();
  ctx.sfJson = () => ({
    result: [
      { SubscriberPackageName: "other", SubscriberPackageVersionId: OLD }
    ]
  });
  assert.equal(installedVersion(ctx), null);
});

test("install-smoke installs only the package, checks metadata, deploys the shim, then proves the gate", async () => {
  const ctx = fakeOrg();
  await smoke.deploy(ctx);
  assert.equal(ctx.installed, NEW);
  assert.ok(!ctx.calls.some((args) => args.includes("sfdx-source/checkr")));
  smoke.setup(ctx);
  const deploy = ctx.calls.find((args) => args[1] === "deploy");
  assert.equal(
    deploy[deploy.indexOf("--source-dir") + 1],
    "/repo/sfdx-source/reference/main/triggers"
  );
  assert.equal(ctx.version, "0.1.0.2");
  assert.ok(ctx.anonymous.some((source) => source.includes("publish")));
  smoke.run(ctx);
  assert.ok(ctx.checks.length >= 6);
  assert.deepEqual(
    ctx.checks.filter((check) => !check.passed),
    []
  );
});

test("missing packaged metadata fails the smoke checks", () => {
  const ctx = fakeOrg();
  checkPackageMetadata(ctx, {
    permissionSets: ["CKR_Admin"],
    lwc: [],
    supportedObjects: []
  });
  assert.equal(ctx.checks.filter((check) => !check.passed).length, 3);
  assert.match(ctx.checks[0].detail, /CKR_User/);
});

test("install-upgrade upgrades in place, keeps checklist data, and still gates", async () => {
  const ctx = fakeOrg();
  await upgrade.deploy(ctx);
  assert.equal(ctx.installed, OLD);
  upgrade.setup(ctx);
  // The record created after the upgrade has no instance and must be blocked.
  const soql = ctx.soql.bind(ctx);
  ctx.soql = (query) =>
    query.includes("-1'") ? [{ Id: "fresh" }] : soql(query);
  await upgrade.run(ctx);
  upgrade.verify(ctx);
  assert.equal(ctx.installed, NEW);
  assert.equal(ctx.metrics.upgrade, "performed");
  assert.equal(ctx.version, "0.1.0.2");
  assert.ok(
    ctx.checks.some(
      (check) => check.name === "items from the first install survive"
    )
  );
  assert.deepEqual(
    ctx.checks.filter((check) => !check.passed),
    []
  );
});

test("install-upgrade fails when data changes or the gate stops blocking", async () => {
  const ctx = fakeOrg();
  await upgrade.deploy(ctx);
  upgrade.setup(ctx);
  let upgraded = false;
  const sfJson = ctx.sfJson;
  ctx.sfJson = (args) => {
    if (args[0] === "package" && args[1] === "install") upgraded = true;
    if (upgraded && args[0] === "data") return { result: {} };
    return sfJson(args);
  };
  const soql = ctx.soql.bind(ctx);
  ctx.soql = (query) =>
    upgraded && query.includes("CKR_ChecklistInstanceItem__c")
      ? []
      : soql(query);
  await upgrade.run(ctx);
  const failed = ctx.checks.filter((check) => !check.passed).map((c) => c.name);
  assert.ok(failed.includes("items from the first install survive"));
  assert.ok(
    failed.includes("gate still blocks an incomplete record after upgrade")
  );
});

test("install-upgrade without --upgrade-from records a skip and smoke-tests --package", async () => {
  const ctx = fakeOrg();
  ctx.upgradeFrom = undefined;
  await upgrade.deploy(ctx);
  assert.equal(ctx.installed, NEW);
  upgrade.setup(ctx);
  await upgrade.run(ctx);
  upgrade.verify(ctx);
  assert.match(ctx.metrics.upgrade, /^skipped: /);
  assert.equal(ctx.calls.filter((args) => args[1] === "install").length, 1);
  assert.deepEqual(
    ctx.checks.filter((check) => !check.passed),
    []
  );
});
