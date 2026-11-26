import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs, runHarness, loadScenarios } from "../harness.mjs";
import { updateCatalog } from "../lib/evidence.mjs";
import {
  readMetrics,
  cleanup,
  withAuditMaintenance
} from "../lib/fixtures.mjs";
import { compareTests, runAer } from "../lib/aer.mjs";
import { installPackage } from "../lib/install.mjs";
import { createIdentities } from "../lib/identities.mjs";
import { verifyBulk } from "../scenarios/bulk-200.mjs";
import insert from "../scenarios/insert-gating.mjs";
import { verifyCutover } from "../scenarios/version-cutover.mjs";
import bypass, { verifyBypass } from "../scenarios/bypass.mjs";
import auditIntegrity from "../scenarios/audit-integrity.mjs";
import gate from "../scenarios/gate-block-pass.mjs";

function temp(t) {
  const root = mkdtempSync(join(tmpdir(), "checkr-harness-"));
  t.after(() => rmSync(root, { force: true, recursive: true }));
  return root;
}
function context() {
  return {
    fixtureKey: "fixture",
    users: new Map([["worker", "worker@example.test"]]),
    checks: [],
    metrics: {},
    artifacts: {},
    check(name, passed, detail) {
      this.checks.push({ name, passed, detail });
    },
    metric(name, value) {
      this.metrics[name] = value;
    },
    artifact(name, value) {
      this.artifacts[name] = value;
    }
  };
}

test("org choice is validated before any CLI, git, or evidence side effects", async () => {
  assert.throws(
    () => parseArgs(["--scenario", "bulk-200"]),
    /pass --org <alias> or --create-scratch/
  );
  assert.throws(
    () =>
      parseArgs(["--scenario", "bulk-200", "--org", "dev", "--create-scratch"]),
    /mutually exclusive/
  );
  assert.equal(
    parseArgs(["--scenario", "bulk-200", "--create-scratch"]).createScratch,
    true
  );
  await assert.rejects(
    runHarness(
      { scenarios: ["bulk-200"] },
      {
        git: () => {
          assert.fail("must not touch git");
        }
      }
    ),
    /pass --org/
  );
});

test("all scenario contracts load", async () => {
  const scenarios = await loadScenarios([
    "apex-local-tests",
    "gate-block-pass",
    "insert-gating",
    "bulk-200",
    "version-cutover",
    "bypass",
    "audit-integrity"
  ]);
  assert.equal(scenarios.length, 7);
  assert.ok(scenarios.every((scenario) => scenario.description));
});

test("catalog changes exactly one latest link and preserves other rows", (t) => {
  const root = temp(t);
  writeFileSync(
    join(root, "README.md"),
    "Intro\n| `insert-gating`   | before insert | pending |\n| `bulk-200` | bulk | pending |\n"
  );
  updateCatalog(root, "insert-gating", join(root, "2026-10-19-insert-gating"));
  const content = readFileSync(join(root, "README.md"), "utf8");
  assert.match(
    content,
    /\| before insert \| \[latest\]\(2026-10-19-insert-gating\/README.md\) \|/
  );
  assert.ok(content.endsWith("| `bulk-200` | bulk | pending |\n"));
});

test("Apex metrics parser fails closed for absent or malformed JSON", () => {
  assert.deepEqual(
    readMetrics({
      logs: '12|USER_DEBUG|[1]|DEBUG|CKR_EVIDENCE={"blocked":false}\n'
    }),
    { blocked: false }
  );
  assert.throws(() => readMetrics({ logs: "unrelated" }), /not found/);
  assert.throws(
    () => readMetrics({ logs: "|DEBUG|CKR_EVIDENCE=broken" }),
    SyntaxError
  );
});

test("bulk verifier rejects wrong identities, non-gate errors, missing rows and excessive queries", () => {
  const outcomes = Array.from({ length: 200 }, (_, index) => ({
    expectedAllowed: index < 100,
    success: index < 100,
    errors: index < 100 ? [] : ["fixture requires completion"]
  }));
  for (const variant of ["valid", "wrong", "permission", "missing", "budget"]) {
    const ctx = context();
    const rows = structuredClone(outcomes);
    if (variant === "wrong") rows[100].success = true;
    if (variant === "permission") rows[100].errors = ["insufficient access"];
    if (variant === "missing") rows.pop();
    verifyBulk(ctx, {
      outcomes: rows,
      soqlCount: variant === "budget" ? 7 : 6,
      cpuMs: 25
    });
    assert.equal(
      ctx.checks.every((check) => check.passed),
      variant === "valid",
      variant
    );
    assert.equal(
      ctx.artifacts["bulk-results.json"].outcomes.length,
      rows.length
    );
  }
});

test("D3 accepts only ungated inserts", () => {
  for (const result of [
    { blocked: false, errors: [] },
    { blocked: true, errors: ["fixture requires completion"] },
    { blocked: true, errors: ["validation failed"] }
  ]) {
    const ctx = context();
    ctx.runAnonymous = () => ({
      logs: `|DEBUG|CKR_EVIDENCE=${JSON.stringify(result)}`
    });
    insert.run(ctx);
    assert.equal(ctx.checks[0].passed, !result.blocked);
    assert.equal(ctx.metrics.insertBlocked, result.blocked);
  }
});

test("gate scenario uses non-admin API session, completes via application, and verifies persisted save", () => {
  const ctx = context();
  ctx.worker = "worker@example.test";
  ctx.soql = (query) =>
    query.includes("SELECT Rating")
      ? [{ Rating: "Hot" }]
      : [{ Id: "001000000000001AAA" }];
  let calls = 0,
    completed = false;
  ctx.sfJson = (args) => {
    assert.equal(args[args.indexOf("--target-org") + 1], ctx.worker);
    if (++calls === 1)
      throw Object.assign(new Error("fixture requires completion"), {
        payload: { status: 1 }
      });
    assert.ok(completed);
    return { status: 0 };
  };
  ctx.runAnonymous = (source) => {
    assert.match(source, /CKR_ChecklistViewerController.updateChecklistItem/);
    completed = true;
  };
  gate.run(ctx);
  assert.equal(calls, 2);
  assert.ok(ctx.checks.every((check) => check.passed));
});

test("gate scenario refuses permission errors and unexpected successful first saves", () => {
  for (const throws of [true, false]) {
    const ctx = context();
    ctx.soql = () => [{ Id: "account" }];
    ctx.sfJson = () => {
      if (throws) throw new Error("insufficient privileges");
      return {};
    };
    ctx.runAnonymous = () => assert.fail("must not complete checklist");
    assert.throws(() => gate.run(ctx), /Expected gate error/);
    assert.equal(ctx.checks[0].passed, false);
  }
});

test("cleanup is scoped to fixture key and does nothing before seeding", () => {
  cleanup({ runAnonymous: () => assert.fail("no fixture") });
  let source;
  cleanup({
    fixtureKey: "CKREvidence123",
    sfJson: () => ({ result: { username: "caller@example.test" } }),
    soql: () => [{ Id: "existing-grant" }],
    runAnonymous: (value) => {
      source = value;
    }
  });
  assert.match(source, /String prefix='CKREvidence123%'/);
  assert.match(source, /WHERE CKR_DeveloperName__c LIKE :prefix/);
  assert.match(source, /WHERE Name LIKE :prefix/);
});

test("AER comparison records missing and divergent methods", () => {
  const org = [
    { ApexClass: { Name: "Example" }, MethodName: "same", Outcome: "Pass" },
    { ApexClass: { Name: "Example" }, MethodName: "diff", Outcome: "Fail" }
  ];
  const aer = [
    { testName: "Example.same", passed: true },
    { testName: "Example.diff", passed: true },
    { testName: "Example.extra", passed: false }
  ];
  assert.deepEqual(compareTests(org, aer), [
    { name: "Example.diff", org: false, aer: true },
    { name: "Example.extra", org: "missing", aer: false }
  ]);
});

test("AER runs fresh source with CKR_Admin and preserves nonzero exit", (t) => {
  const result = runAer(temp(t), (bin, args) => {
    assert.equal(bin, "aer");
    assert.deepEqual(args.slice(0, 4), [
      "test",
      "sfdx-source/checkr",
      "-p",
      "CKR_Admin"
    ]);
    writeFileSync(
      args[4].slice(7),
      '{"testName":"Example.test","passed":false}\n'
    );
    return { status: 1, stdout: "failed", stderr: "" };
  });
  assert.equal(result.status, 1);
  assert.equal(result.tests[0].passed, false);
});

test("package install polls pending requests and fails on errors or timeout", async () => {
  const success = await installPackage(
    (args) => ({
      result: args.includes("report")
        ? { Status: "SUCCESS" }
        : { Status: "IN_PROGRESS", Id: "request" }
    }),
    "04t000000000001AAA",
    { sleep: async () => {} }
  );
  assert.equal(success.status, "SUCCESS");
  await assert.rejects(
    installPackage(
      () => ({ result: { Status: "ERROR" } }),
      "04t000000000001AAA"
    ),
    /failed/
  );
  let now = 0;
  await assert.rejects(
    installPackage(
      () => ({ result: { Status: "IN_PROGRESS", Id: "request" } }),
      "04t000000000001AAA",
      {
        timeoutMs: 1,
        now: () => now++,
        sleep: async () => {}
      }
    ),
    /timed out/
  );
});

test("identity cleanup removes only newly added grants and deactivates only newly created user", () => {
  const calls = [];
  const ensure = createIdentities({
    org: "org",
    orgId: "00D000000000001AAA",
    users: new Map(),
    soql: (query) =>
      query.includes("FROM Profile")
        ? [{ Id: "profile" }]
        : query.includes("FROM PermissionSetAssignment")
          ? calls.some((args) => args.includes("permset"))
            ? [{ Id: "assignment" }]
            : []
          : calls.some((args) => args.includes("create"))
            ? [{ Id: "newUser" }]
            : [],
    sfJson: (args) => {
      calls.push(args);
      return { status: 0 };
    }
  });
  ensure({
    key: "worker",
    profile: "Standard User",
    license: "Salesforce",
    permissionSets: ["CKR_User"]
  });
  ensure.cleanup();
  assert.ok(
    calls.some((args) => args.includes("assignment") && args.includes("delete"))
  );
  assert.ok(
    calls.some(
      (args) => args.includes("newUser") && args.includes("IsActive=false")
    )
  );
});

test("cutover evidence rejects absent or divergent results", () => {
  const valid = {
    completedSaved: true,
    newBlocked: true,
    errors: ["fixture v2 requires completion"],
    publishedCount: 1,
    oldStatus: "Historical",
    ruleEditRejected: true
  };
  for (const field of [
    null,
    "completedSaved",
    "newBlocked",
    "errors",
    "publishedCount",
    "oldStatus",
    "ruleEditRejected"
  ]) {
    const ctx = context();
    const result = { ...valid };
    if (field) delete result[field];
    verifyCutover(ctx, result);
    assert.equal(
      ctx.checks.every((check) => check.passed),
      field === null,
      field ?? "valid"
    );
  }
});

test("bypass evidence rejects missing, extra, or incomplete audit rows", () => {
  const expected = {
    recordId: "record",
    actorId: "actor",
    ruleId: "rule",
    source: "CustomPermission"
  };
  const event = {
    CKR_RecordId__c: "record",
    CKR_Actor__c: "actor",
    CKR_GateRule__c: "rule",
    CKR_ObjectApiName__c: "Account",
    CKR_Source__c: "CustomPermission",
    CKR_OccurredOn__c: "2026-10-19T00:00:00Z",
    CKR_Details__c: "blocked"
  };
  for (const rows of [
    [event],
    [],
    [event, event],
    ...Object.keys(event).map((key) => [{ ...event, [key]: null }])
  ]) {
    const ctx = context();
    verifyBypass(ctx, rows, expected);
    assert.equal(
      ctx.checks[0].passed,
      rows.length === 1 && Object.values(rows[0]).every(Boolean)
    );
  }
});

test("bypass scenario uses separate API users, proves the blocked baseline, and checks saved audit rows", () => {
  const ctx = context();
  ctx.bypassUsers = [
    { username: "permission@example.test", Id: "permission" },
    { username: "setting@example.test", Id: "setting" }
  ];
  let activeSource;
  const enabled = new Set();
  const calls = [];
  ctx.runAnonymous = (source) => {
    const actor = source.includes("'permission'") ? "permission" : "setting";
    enabled.add(actor);
  };
  ctx.soql = (query) => {
    if (query.includes("FROM CKR_ChecklistGateRule__c"))
      return [{ Id: "rule" }];
    if (query.includes("SELECT Rating")) return [{ Rating: "Hot" }];
    if (query.includes("FROM CKR_GateBypassEvent__c"))
      return [
        {
          CKR_Actor__c:
            activeSource === "CustomPermission" ? "permission" : "setting",
          CKR_RecordId__c:
            activeSource === "CustomPermission"
              ? "account-permission"
              : "account-setting",
          CKR_ObjectApiName__c: "Account",
          CKR_GateRule__c: "rule",
          CKR_Source__c: activeSource,
          CKR_OccurredOn__c: "2026-10-19T00:00:00Z",
          CKR_Details__c: "fixture requires completion"
        }
      ];
    return [
      {
        Id: query.includes("fixture-setting")
          ? "account-setting"
          : "account-permission"
      }
    ];
  };
  ctx.sfJson = (args) => {
    const username = args[args.indexOf("--target-org") + 1];
    calls.push(username);
    const actor = username.startsWith("permission") ? "permission" : "setting";
    if (!enabled.has(actor)) throw new Error("fixture requires completion");
    activeSource =
      actor === "permission" ? "CustomPermission" : "CustomSetting";
    return { status: 0 };
  };
  bypass.run(ctx);
  assert.equal(calls.length, 5);
  assert.ok(ctx.checks.every((check) => check.passed));
  assert.equal(ctx.checks.length, 5);
});

test("temporary maintenance is revoked after failures and existing grants are preserved", () => {
  for (const held of [true, false]) {
    let queried = 0;
    const calls = [];
    const ctx = {
      soql: () => (++queried === 1 && !held ? [] : [{ Id: "grant" }]),
      sfJson: (args) => {
        calls.push(args);
        return {};
      }
    };
    assert.throws(
      () =>
        withAuditMaintenance(
          ctx,
          () => {
            throw new Error("cleanup failed");
          },
          "worker@example.test"
        ),
      /cleanup failed/
    );
    if (held) assert.deepEqual(calls, []);
    else {
      assert.deepEqual(calls[0].slice(0, 3), ["org", "assign", "permset"]);
      assert.deepEqual(calls[1], [
        "data",
        "delete",
        "record",
        "--sobject",
        "PermissionSetAssignment",
        "--record-id",
        "grant"
      ]);
    }
  }
});

test("audit integrity verification requires all seven Apex tests to pass", () => {
  for (const [summary, expected] of [
    [{ outcome: "Passed", testsRan: 7 }, true],
    [{ outcome: "Passed", testsRan: "7" }, true],
    [{ outcome: "Passed", testsRan: 5 }, false],
    [{ outcome: "Failed", testsRan: 7 }, false],
    [undefined, false]
  ]) {
    const ctx = context();
    const result = { result: { summary } };
    ctx.sfJson = (args) => {
      assert.deepEqual(args, [
        "apex",
        "run",
        "test",
        "--tests",
        "CKR_AuditRecordGuardTest",
        "--tests",
        "CKR_AuditMaintenanceIT",
        "--result-format",
        "json",
        "--wait",
        "20"
      ]);
      return result;
    };
    auditIntegrity.verify(ctx);
    assert.equal(ctx.checks.length, 1);
    assert.equal(ctx.checks[0].passed, expected);
    assert.equal(ctx.artifacts["apex-results.json"], result);
  }
});

test("audit integrity requires authorization failures and verifies maintenance deletes", () => {
  for (const expectedDenial of [true, false]) {
    const ctx = context();
    ctx.auditActor = { username: "worker@example.test" };
    let maintenance = false;
    let deletes = 0;
    ctx.soql = (query) => {
      if (query.includes("PermissionSetAssignment"))
        return maintenance ? [{ Id: "grant" }] : [];
      if (query.includes("FROM CKR_ChecklistInstance__c"))
        return [{ Id: "instance", CKR_ParentRecordId__c: "parent" }];
      if (deletes === 2) return [];
      return [
        {
          Id: query.includes("FROM CKR_ChecklistAuditEvent__c")
            ? "audit"
            : "bypass"
        }
      ];
    };
    ctx.sfJson = (args) => {
      if (args[0] === "org") {
        maintenance = true;
        return {};
      }
      const object = args[args.indexOf("--sobject") + 1];
      if (object === "PermissionSetAssignment") {
        maintenance = false;
        return {};
      }
      assert.equal(
        args[args.indexOf("--target-org") + 1],
        "worker@example.test"
      );
      if (!maintenance) {
        if (object === "CKR_ChecklistInstance__c")
          throw new Error("CheckR audit records are append-only");
        if (!expectedDenial) throw new Error("unrelated network failure");
        const label =
          object === "CKR_ChecklistAuditEvent__c"
            ? "Checklist Audit Event"
            : "Gate Bypass Event";
        const error = new Error(
          args[1] === "update"
            ? `entity type cannot be updated: ${label}`
            : "insufficient access rights on object id"
        );
        error.name =
          args[1] === "update"
            ? "CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY"
            : "INSUFFICIENT_ACCESS_OR_READONLY";
        throw error;
      }
      if (args[1] === "delete") deletes++;
      return {};
    };
    auditIntegrity.run(ctx);
    assert.equal(deletes, 2);
    assert.equal(maintenance, false);
    assert.equal(ctx.checks.length, 6);
    assert.equal(
      ctx.checks.every((check) => check.passed),
      expectedDenial
    );
  }
});
