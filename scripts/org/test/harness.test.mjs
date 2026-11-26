import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  existsSync
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs, runHarness } from "../harness.mjs";
import { createSfJson, SfError, sfFailureDetail } from "../lib/sf.mjs";
import {
  createRedactor,
  renderSummary,
  trimLog,
  writeArtifact
} from "../lib/evidence.mjs";
import { createIdentities, usernameFor } from "../lib/identities.mjs";
import { createApex } from "../lib/apex.mjs";
import localTests, {
  coverageSummary,
  packageApexNames,
  packageCoverage
} from "../scenarios/apex-local-tests.mjs";

const orgId = "00D000000000001AAA";
function temp(t) {
  const dir = mkdtempSync(join(tmpdir(), "checkr-evidence-test-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  return dir;
}

test("CLI requires named scenarios, validates values, and supports reuse/keep", () => {
  assert.deepEqual(
    parseArgs([
      "--scenario",
      "one,two",
      "--scenario",
      "one",
      "--org",
      "dev",
      "--keep"
    ]),
    { scenarios: ["one", "two"], org: "dev", keep: true }
  );
  for (const args of [
    [],
    ["--scenario"],
    ["--org", "--keep"],
    ["--scenario", "../bad"],
    ["--scenario", "one,"],
    ["--unknown"]
  ])
    assert.throws(() => parseArgs(args));
  assert.equal(parseArgs(["--help"]).help, true);
});

test("Salesforce JSON wrapper captures output and typed errors without inheriting stdio", () => {
  const results = [];
  const sf = createSfJson({
    execute: (bin, args, options) => {
      assert.equal(bin, "sf");
      assert.equal(args.at(-1), "--json");
      assert.deepEqual(options.stdio, ["ignore", "pipe", "pipe"]);
      return '{"status":0,"result":{"ok":true}}';
    },
    onResult: (result) => results.push(result)
  });
  assert.equal(sf(["org", "display"]).result.ok, true);
  assert.equal(results.length, 1);
  for (const throws of [false, true]) {
    const failed = createSfJson({
      execute: () => {
        const stdout =
          '{"status":7,"name":"DeployError","message":"bad deploy"}';
        if (throws) throw Object.assign(new Error(), { stdout, status: 7 });
        return stdout;
      }
    });
    assert.throws(
      () => failed([]),
      (error) =>
        error instanceof SfError &&
        error.status === 7 &&
        error.name === "DeployError" &&
        error.message === "bad deploy"
    );
  }
  assert.throws(() => createSfJson({ execute: () => "not json" })([]), {
    name: "SfInvalidResponse"
  });
});

test("Salesforce CLI failures without a message keep Apex and CLI detail", () => {
  const apexFailure = createSfJson({
    execute: () => {
      throw Object.assign(new Error("exit 1"), {
        status: 1,
        stderr: "plugin warning",
        stdout: JSON.stringify({
          status: 1,
          result: {
            success: false,
            compiled: true,
            exceptionMessage: "System.QueryException: List has no rows",
            exceptionStackTrace: "AnonymousBlock: line 3, column 1"
          }
        })
      });
    }
  });
  assert.throws(
    () => apexFailure(["apex", "run", "--target-org", "x"]),
    (error) =>
      error instanceof SfError &&
      error.message === "System.QueryException: List has no rows" &&
      error.detail.exceptionStackTrace === "AnonymousBlock: line 3, column 1" &&
      error.detail.stderr === "plugin warning" &&
      error.command.join(" ") === "apex run --target-org"
  );
  const deployFailure = createSfJson({
    execute: () =>
      JSON.stringify({
        status: 1,
        result: { details: { componentFailures: [{ problem: "Bad field" }] } }
      })
  });
  assert.throws(
    () => deployFailure(["project", "deploy", "start"]),
    (error) =>
      /Bad field/.test(error.message) && /Bad field/.test(error.detail.failures)
  );
  assert.deepEqual(sfFailureDetail({ status: 1 }), {});
  assert.equal(
    sfFailureDetail({ result: { failures: ["x".repeat(5000)] } }).failures
      .length,
    4001
  );
});

test("evidence redacts sensitive fields, free-text usernames, tokens, and auth URLs", (t) => {
  const redact = createRedactor();
  redact({ accessToken: "opaque-secret-value", password: "password-secret" });
  const data = redact({
    username: "private@example.test",
    nested: { sfdxAuthUrl: "force://secret" },
    log: "opaque-secret-value password-secret private@example.test https://host/secur/frontdoor.jsp?sid=123 force://secret Bearer abc 00D000000000001!token"
  });
  const json = JSON.stringify(data);
  for (const secret of [
    "private@example",
    "opaque-secret-value",
    "password-secret",
    "force://",
    "sid=123",
    "Bearer abc",
    "!token"
  ])
    assert.ok(!json.includes(secret), secret);
  assert.equal(
    redact({ instanceUrl: "https://example.my.salesforce.com" }).instanceUrl,
    "https://example.my.salesforce.com"
  );
  const dir = temp(t);
  assert.throws(() => writeArtifact(dir, "../escape.json", {}, redact));
  writeArtifact(dir, "large.json", { log: "x".repeat(300000) }, redact);
  assert.equal(
    JSON.parse(readFileSync(join(dir, "large.json"))).truncated,
    true
  );
});

test("logs retain at most 200 lines and 256KB, including multibyte text", () => {
  assert.equal(
    trimLog(Array.from({ length: 300 }, (_, i) => String(i)).join("\n")).split(
      "\n"
    )[0],
    "100"
  );
  assert.ok(Buffer.byteLength(trimLog("é".repeat(300000))) <= 256 * 1024);
});

test("summary rendering preserves checks, metrics and dirty provenance", () => {
  const fixture = {
    scenario: "sample",
    outcome: "failed",
    startedAt: "2026-10-17T00:00:00Z",
    finishedAt: "2026-10-17T00:01:00Z",
    commit: "abcdef",
    dirty: true,
    packageVersion: null,
    checks: [{ name: "Coverage", outcome: "failed", detail: "74%" }],
    metrics: { coveragePercent: 74 }
  };
  const markdown = renderSummary(fixture);
  for (const expected of [
    "**failed**",
    "abcdef (dirty)",
    "source deploy",
    "failed: Coverage — 74%",
    '"coveragePercent": 74'
  ])
    assert.ok(markdown.includes(expected));
});

test("deterministic usernames and identities reuse users and assign permsets", (t) => {
  assert.equal(
    usernameFor("admin", orgId),
    "admin.00D000000000001@checkr-evidence.test"
  );
  assert.throws(() => usernameFor("../admin", orgId));
  assert.throws(() => usernameFor("admin", "bad"));
  temp(t);
  const users = new Map();
  let exists = false;
  let definition;
  let definitionFile;
  const calls = [];
  const ensure = createIdentities({
    org: "test",
    orgId,
    users,
    soql: (query) =>
      query.includes("FROM Profile")
        ? [{ Id: "profile" }]
        : query.includes("FROM PermissionSetAssignment")
          ? exists
            ? [{ PermissionSet: { Name: "CKR_Admin" } }]
            : []
          : exists
            ? [{ ProfileId: "profile", IsActive: true }]
            : [],
    sfJson: (args) => {
      calls.push(args);
      if (args.includes("--definition-file")) {
        definitionFile = args[args.indexOf("--definition-file") + 1];
        definition = JSON.parse(readFileSync(definitionFile));
      }
      return { status: 0 };
    }
  });
  const spec = {
    key: "reader",
    license: "Salesforce",
    profile: "Standard User",
    permissionSets: ["CKR_Admin", "CKR_ReadOnly"]
  };
  assert.deepEqual(ensure(spec), {
    key: "reader",
    license: "Salesforce",
    permissionSets: ["CKR_Admin", "CKR_ReadOnly"]
  });
  assert.equal(definition.profileId, "profile");
  const assignment = calls.find((args) => args.includes("permset"));
  assert.deepEqual(assignment.slice(5, 9), [
    "--name",
    "CKR_Admin",
    "--name",
    "CKR_ReadOnly"
  ]);
  assert.equal(existsSync(definitionFile), false);
  exists = true;
  ensure(spec);
  assert.equal(calls.filter((args) => args.includes("create")).length, 1);
  // A reused user is only assigned the permission sets it does not hold yet.
  const reassigned = calls.filter((args) => args.includes("permset"));
  assert.equal(reassigned.length, 2);
  assert.deepEqual(reassigned[1].slice(5), [
    "--name",
    "CKR_ReadOnly",
    "--on-behalf-of",
    usernameFor("reader", orgId)
  ]);
  assert.equal(users.get("reader"), usernameFor("reader", orgId));
});

test("anonymous Apex uses separate authenticated identities and removes temp files", () => {
  let path;
  const apex = createApex({
    org: "admin",
    users: new Map([["reader", "reader-user"]]),
    sfJson: (args) => {
      assert.equal(args[args.indexOf("--target-org") + 1], "reader-user");
      path = args.at(-1);
      assert.equal(readFileSync(path, "utf8"), "System.debug('test');");
      return { result: { success: false, exceptionMessage: "denied" } };
    }
  });
  assert.throws(
    () => apex.runAnonymous("System.debug('test');", { asUser: "reader" }),
    /denied/
  );
  assert.equal(existsSync(path), false);
  assert.throws(
    () => apex.runAnonymous("", { asUser: "unknown" }),
    /Unknown identity/
  );
});

test("async waiting handles holding jobs, returns failures, and times out", async () => {
  let clock = 0;
  let status = "Holding";
  const apex = createApex({
    org: "test",
    now: () => clock,
    sleep: async (ms) => {
      clock += ms;
      status = "Failed";
    },
    sfJson: () => ({
      result: { records: [{ Status: status, NumberOfErrors: 1 }] }
    })
  });
  const params = {
    classNames: ["wdn_Worker"],
    since: "2026-10-17T00:00:00Z",
    timeoutMs: 1000
  };
  assert.equal((await apex.waitForAsync(params))[0].Status, "Failed");
  const stuck = createApex({
    org: "test",
    now: () => clock,
    sleep: async (ms) => {
      clock += ms;
    },
    sfJson: () => ({ result: { records: [{ Status: "Processing" }] } })
  });
  await assert.rejects(stuck.waitForAsync(params), /Timed out/);
  await assert.rejects(
    stuck.waitForAsync({ ...params, classNames: ["bad'"] }),
    /classNames/
  );
});

test("coverage computes class and overall percentages and rejects missing coverage", () => {
  const coverage = {
    coverage: [{ name: "Example", totalLines: 20, totalUncovered: 4 }]
  };
  assert.equal(coverageSummary({ coverage }).overall, 80);
  assert.equal(
    coverageSummary({ coverage, summary: { orgWideCoverage: "76%" } }).overall,
    76
  );
  assert.equal(coverageSummary({}).overall, null);
  const reported = coverageSummary({
    coverage: {
      coverage: [{ name: "Example", totalLines: 20, totalCovered: 17 }]
    }
  });
  assert.equal(reported.classes[0].coveredLines, 17);
  assert.equal(reported.overall, 85);
  assert.equal(
    coverageSummary({
      coverage: { coverage: [{ name: "Example", totalLines: 20 }] }
    }).classes[0].percent,
    null
  );
});

test("package coverage counts only Apex under sfdx-source/checkr", () => {
  const names = packageApexNames(process.cwd());
  assert.ok(names.has("CKR_AppFactory"));
  assert.ok(names.size > 10);
  assert.ok(!names.has("CheckrSmokeSeed"));
  assert.ok(!names.has("CKR_AccountTrigger"));
  const classes = [
    { name: "CKR_AppFactory", coveredLines: 9, totalLines: 10 },
    { name: "CheckrSmokeSeed", coveredLines: 0, totalLines: 90 }
  ];
  assert.equal(packageCoverage(classes, names), 90);
  assert.equal(packageCoverage([], names), null);
});

async function exercise(
  t,
  {
    reuse = false,
    keep = false,
    failCommand,
    scenarioError,
    needsOrgTests = false,
    local = false,
    lowCoverage = false,
    failedLocalTests = false,
    scenarioSfError = false,
    cleanupError = false
  } = {}
) {
  const evidenceRoot = join(temp(t), "evidence");
  const commands = [];
  const logs = [];
  const execute = (bin, args) => {
    commands.push(args);
    assert.equal(args.at(-1), "--json");
    if (failCommand && args.slice(0, 3).join(" ") === failCommand)
      throw Object.assign(new Error("raw secret"), {
        status: 1,
        stdout: JSON.stringify({
          status: 1,
          name: "Failure",
          message: "failed private@example.test",
          accessToken: "never-save-this"
        })
      });
    let result = {};
    if (args.includes("display"))
      result = {
        instanceUrl: "https://example.my.salesforce.com",
        devHubId: "hub",
        username: "admin@example.test",
        accessToken: "never-save-this"
      };
    if (args.includes("query"))
      result = { records: [{ Id: orgId, OrganizationType: "Developer" }] };
    if (args.includes("test"))
      result = {
        summary: {
          outcome: failedLocalTests ? "Failed" : "Passed",
          passing: failedLocalTests ? 2 : 3,
          failing: failedLocalTests ? 1 : 0,
          testsRan: 3,
          orgWideCoverage: lowCoverage ? "84%" : "90%"
        },
        tests: [
          {
            ApexClass: { Name: "Example" },
            MethodName: "test",
            Outcome: failedLocalTests ? "Fail" : "Pass",
            Message: failedLocalTests ? "sharing denied ".repeat(100) : null
          },
          {
            ApexClass: { Name: "Example" },
            MethodName: "two",
            Outcome: "Pass"
          },
          {
            ApexClass: { Name: "Example" },
            MethodName: "three",
            Outcome: "Pass"
          }
        ],
        coverage: {
          coverage: [
            { name: "CKR_AppFactory", totalLines: 10, totalCovered: 9 },
            { name: "Example", totalLines: 10, totalUncovered: 2 }
          ]
        }
      };
    if (failedLocalTests && args.includes("test"))
      throw Object.assign(new Error("tests failed"), {
        status: 100,
        stdout: JSON.stringify({ status: 100, result })
      });
    return JSON.stringify({ status: 0, result });
  };
  let cleanupCount = 0;
  const scenario = {
    name: "sample",
    needsOrgTests,
    async setup() {},
    async run(ctx) {
      ctx.artifact("scenario/action.json", { token: "never-save-this" });
      if (scenarioError) throw new Error("scenario failed");
      if (scenarioSfError)
        throw new SfError(
          {
            status: 1,
            result: {
              success: false,
              exceptionMessage:
                "System.DmlException: lock for private@example.test",
              exceptionStackTrace: "AnonymousBlock: line 7, column 1"
            }
          },
          1,
          ["apex", "run", "--target-org"]
        );
      ctx.check("sample check", true);
    },
    async verify() {},
    async cleanup() {
      cleanupCount++;
      if (cleanupError) throw new Error("fixture cleanup failed");
    }
  };
  const code = await runHarness(
    {
      scenarios: ["sample"],
      keep,
      ...(reuse ? { org: "existing" } : { createScratch: true })
    },
    {
      scenarios: local
        ? [localTests]
        : [scenario, { ...scenario, name: "second" }],
      evidenceRoot,
      execute,
      runAer: () => ({
        status: 0,
        tests: [{ testName: "Example.test", passed: true }]
      }),
      git: (args) => (args[0] === "rev-parse" ? "abcdef123456789" : ""),
      log: (line) => logs.push(line),
      env: {}
    }
  );
  const folders = readdirSync(evidenceRoot).map((name) =>
    join(evidenceRoot, name)
  );
  const summaries = folders.map((dir) =>
    JSON.parse(readFileSync(join(dir, "summary.json")))
  );
  for (const folder of folders) {
    for (const file of [
      "summary.json",
      "README.md",
      "scenario/sf-calls.json"
    ]) {
      const text = readFileSync(join(folder, file), "utf8");
      assert.ok(!text.includes("never-save-this"));
      assert.ok(!text.includes("private@example.test"));
      assert.ok(!text.includes("admin@example.test"));
    }
  }
  return { code, commands, logs, summaries, folders, cleanupCount };
}

test("explicit scratch mode deploys both source directories and deletes only its created org", async (t) => {
  const result = await exercise(t, { needsOrgTests: true });
  assert.equal(result.code, 0);
  assert.equal(result.summaries.length, 2);
  assert.ok(
    result.summaries.every((s) => s.outcome === "passed" && s.org.scratch)
  );
  const deployments = result.commands.filter((args) => args.includes("deploy"));
  assert.equal(deployments.length, 1);
  assert.ok(deployments[0].some((arg) => arg.endsWith("/sfdx-source/checkr")));
  assert.ok(
    deployments[0].some((arg) => arg.endsWith("/sfdx-source/reference"))
  );
  assert.equal(
    result.commands.filter((args) => args.includes("delete")).length,
    1
  );
});

test("reused and kept orgs are retained; only the two source packages are deployed", async (t) => {
  for (const config of [{ reuse: true }, { keep: true }]) {
    const result = await exercise(t, config);
    assert.equal(result.code, 0);
    assert.ok(!result.commands.some((args) => args.includes("delete")));
    assert.equal(
      result.commands.filter((args) => args.includes("deploy")).length,
      1
    );
    if (config.reuse)
      assert.ok(!result.commands.some((args) => args.includes("create")));
    if (config.keep)
      assert.ok(
        result.logs.some((line) => line.startsWith("Kept scratch org alias:"))
      );
  }
});

test("source deployments preserve conflict protection for scratch and reused orgs", async (t) => {
  for (const config of [{}, { reuse: true }]) {
    const result = await exercise(t, config);
    assert.equal(result.code, 0);
    const deployments = result.commands.filter((args) =>
      args.includes("deploy")
    );
    assert.equal(deployments.length, 1);
    assert.ok(
      !deployments[0].includes("--ignore-conflicts"),
      "Shared deployments must preserve source-tracking conflict protection"
    );
  }
});

test("initialization, phase, and cleanup failures write evidence and fail the run", async (t) => {
  for (const config of [
    { failCommand: "org create scratch" },
    { failCommand: "project deploy start" },
    { scenarioError: true },
    { failCommand: "org delete scratch" }
  ]) {
    const result = await exercise(t, config);
    assert.equal(result.code, 1);
    assert.ok(result.summaries.every((s) => s.outcome === "error"));
    assert.equal(
      result.commands.some((args) => args.includes("delete")),
      config.failCommand !== "org create scratch"
    );
  }
});

test("scenario CLI failures write Apex detail to error.json", async (t) => {
  const result = await exercise(t, { scenarioSfError: true });
  assert.equal(result.code, 1);
  const error = JSON.parse(
    readFileSync(join(result.folders[0], "scenario/error.json"), "utf8")
  );
  assert.deepEqual(error.command, ["apex", "run", "--target-org"]);
  assert.match(error.message, /^System\.DmlException: lock for /);
  assert.ok(!error.message.includes("private@example.test"));
  assert.equal(
    error.detail.exceptionStackTrace,
    "AnonymousBlock: line 7, column 1"
  );
  assert.match(result.summaries[0].checks.at(-1).detail, /DmlException/);
});

test("built-in tests save results and coverage; CLI failure saves Apex error output", async (t) => {
  const passed = await exercise(t, { local: true });
  assert.equal(passed.code, 0);
  const summary = JSON.parse(
    readFileSync(join(passed.folders[0], "coverage-summary.json"))
  );
  assert.equal(summary.overall, 90);
  assert.equal(summary.classes[0].percent, 90);
  assert.equal(summary.classes[1].percent, 80);
  const failed = await exercise(t, {
    local: true,
    failCommand: "apex run test"
  });
  assert.equal(failed.code, 1);
  assert.equal(
    JSON.parse(readFileSync(join(failed.folders[0], "apex-results.json")))
      .status,
    1
  );
});

test("structured evidence keeps class records beyond 200 formatted lines", (t) => {
  const folder = temp(t);
  const records = Array.from({ length: 100 }, (_, index) => ({
    name: `Example${index}`,
    percent: 80
  }));
  writeArtifact(
    folder,
    "coverage.json",
    { classes: records },
    createRedactor()
  );
  assert.equal(
    JSON.parse(readFileSync(join(folder, "coverage.json"))).classes.length,
    100
  );
});

test("invalid Salesforce envelopes produce typed errors", () => {
  for (const output of ["null", "[]", "{}", "42"]) {
    assert.throws(() => createSfJson({ execute: () => output })([]), {
      name: "SfInvalidResponse"
    });
  }
});

test("failed coverage checks fail the run without becoming execution errors", async (t) => {
  const result = await exercise(t, { local: true, lowCoverage: true });
  assert.equal(result.code, 1);
  assert.equal(result.summaries[0].outcome, "failed");
  assert.equal(
    result.summaries[0].checks.find((check) =>
      check.name.startsWith("Overall Apex coverage")
    ).outcome,
    "failed"
  );
});

test("failed real-org tests retain counts, coverage and bounded AER differences", async (t) => {
  const result = await exercise(t, { local: true, failedLocalTests: true });
  assert.equal(result.code, 1);
  const summary = result.summaries[0];
  assert.equal(summary.outcome, "failed");
  assert.deepEqual(summary.metrics, {
    aerTestsPassed: 1,
    aerTestsFailed: 0,
    aerTestsRan: 1,
    testsPassed: 2,
    testsFailed: 1,
    testsRan: 3,
    coveragePercent: 90,
    packageCoveragePercent: 90,
    aerDifferences: [
      {
        name: "Example.test",
        org: false,
        aer: true,
        orgMessage: "sharing denied ".repeat(100).slice(0, 500)
      },
      { name: "Example.three", org: true, aer: "missing" },
      { name: "Example.two", org: true, aer: "missing" }
    ]
  });
  assert.equal(
    summary.checks.find((check) => check.name === "Local Apex tests").outcome,
    "failed"
  );
  assert.equal(summary.checks.at(-1).outcome, "passed");
  const comparison = JSON.parse(
    readFileSync(join(result.folders[0], "aer-comparison.json"))
  );
  assert.deepEqual(comparison.differences, summary.metrics.aerDifferences);
  assert.equal(comparison.orgCount, 3);
  assert.equal(comparison.aerCount, 1);
});

test("real-org CLI infrastructure failures remain errors", async (t) => {
  const result = await exercise(t, {
    local: true,
    failCommand: "apex run test"
  });
  assert.equal(result.code, 1);
  assert.equal(result.summaries[0].outcome, "error");
});

test("fixture cleanup runs after scenario failure, is skipped for keep, and propagates failure", async (t) => {
  const failed = await exercise(t, { scenarioError: true, reuse: true });
  assert.equal(failed.cleanupCount, 2);
  const kept = await exercise(t, { keep: true, scenarioError: true });
  assert.equal(kept.cleanupCount, 0);
  const cleanupFailure = await exercise(t, { cleanupError: true, reuse: true });
  assert.equal(cleanupFailure.code, 1);
  assert.ok(
    cleanupFailure.summaries.every((summary) =>
      summary.checks.some(
        (check) => check.name === "cleanup" && check.outcome === "failed"
      )
    )
  );
});

test("evidence records local paths relative to the repo root or as <home>", () => {
  const redact = createRedactor({
    root: "/home/someone/projects/checkr",
    home: "/home/someone"
  });
  const data = redact({
    filePath: "/home/someone/projects/checkr/sfdx-source/checkr/main/x.cls",
    stack:
      "at run (file:///home/someone/.nvm/node/lib/sf.js:1) at /Users/other/x.js",
    root: "/home/someone/projects/checkr"
  });
  assert.equal(data.filePath, "sfdx-source/checkr/main/x.cls");
  assert.equal(
    data.stack,
    "at run (<home>/.nvm/node/lib/sf.js:1) at <home>/x.js"
  );
  assert.equal(data.root, "");
  assert.ok(!JSON.stringify(data).includes("someone"));
});
