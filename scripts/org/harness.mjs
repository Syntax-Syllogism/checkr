#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { createSfJson, createSfJsonAsync } from "./lib/sf.mjs";
import { createApex } from "./lib/apex.mjs";
import { runAer as executeAer } from "./lib/aer.mjs";
import { ensureAdminPermset } from "./lib/permsets.mjs";
import { createIdentities } from "./lib/identities.mjs";
import {
  updateCatalog,
  createRedactor,
  renderSummary,
  writeArtifact
} from "./lib/evidence.mjs";

export const PACKAGE_VERSION_ID = /^04t[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?$/;

export function parseArgs(args) {
  const options = { scenarios: [], keep: false };
  for (let index = 0; index < args.length; index++) {
    const arg = args[index];
    if (arg === "--create-scratch") options.createScratch = true;
    else if (arg === "--keep") options.keep = true;
    else if (arg === "--help") options.help = true;
    else if (
      ["--scenario", "--org", "--package", "--upgrade-from"].includes(arg)
    ) {
      const value = args[++index];
      if (!value || value.startsWith("--"))
        throw new Error(`Missing value for ${arg}`);
      if (arg === "--org") options.org = value;
      else if (arg === "--scenario")
        options.scenarios.push(...value.split(","));
      else {
        if (!PACKAGE_VERSION_ID.test(value))
          throw new Error(`${arg} expects a package version ID (04t)`);
        options[arg === "--package" ? "package" : "upgradeFrom"] = value;
      }
    } else throw new Error(`Unknown argument: ${arg}`);
  }
  if (!options.help && !options.scenarios.length)
    throw new Error("Specify --scenario <name>[,<name>]");
  if (!options.scenarios.every((name) => /^[a-z][a-z0-9-]*$/.test(name)))
    throw new Error("Invalid scenario name");
  options.scenarios = [...new Set(options.scenarios)];
  validateOrgChoice(options);
  return options;
}

export function validateOrgChoice(options) {
  if (options.help) return;
  if (!options.org && !options.createScratch)
    throw new Error("pass --org <alias> or --create-scratch");
  if (options.org && options.createScratch)
    throw new Error("--org and --create-scratch are mutually exclusive");
}

export async function loadScenarios(names) {
  return Promise.all(
    names.map(async (name) => {
      const scenario = (
        await import(new URL(`./scenarios/${name}.mjs`, import.meta.url))
      ).default;
      if (
        scenario?.name !== name ||
        !["setup", "run", "verify"].every(
          (phase) => typeof scenario[phase] === "function"
        )
      ) {
        throw new Error(`Invalid scenario contract: ${name}`);
      }
      return scenario;
    })
  );
}

export async function runHarness(
  options,
  {
    scenarios,
    execute,
    executeAsync,
    runAer = executeAer,
    root = fileURLToPath(new URL("../../", import.meta.url)),
    evidenceRoot = join(root, "docs/evidence"),
    git = (args) =>
      execFileSync("git", args, { cwd: root, encoding: "utf8" }).trim(),
    log = console.log,
    env = process.env
  } = {}
) {
  validateOrgChoice(options);
  const commit = git(["rev-parse", "HEAD"]);
  const dirty = Boolean(git(["status", "--porcelain"]));
  if (dirty) log("Warning: evidence is from a dirty working tree.");
  const selected = scenarios ?? (await loadScenarios(options.scenarios));
  const project = JSON.parse(
    readFileSync(join(root, "sfdx-project.json"), "utf8")
  );
  const org = options.org ?? `checkr-evidence-${Date.now()}`;
  const redact = createRedactor({ root });
  const calls = [];
  const onResult = (result) => {
    redact(result);
    calls.push(result);
  };
  const sf = createSfJson({ execute, onResult });
  const sfAsync = createSfJsonAsync({ execute: executeAsync, onResult });
  const summaries = [];
  const artifacts = [];
  const startedAt = new Date().toISOString();
  let created = false;
  let orgInfo = {
    edition: null,
    instanceUrl: null,
    apiVersion: project.sourceApiVersion,
    scratch: null
  };
  let initError;
  try {
    try {
      if (options.createScratch) {
        sf([
          "org",
          "create",
          "scratch",
          "--definition-file",
          join(root, "config/project-scratch-def.json"),
          "--alias",
          org,
          "--target-dev-hub",
          env.DEVHUB_ALIAS ?? "devHub",
          "--duration-days",
          env.SCRATCH_DURATION ?? "1",
          "--wait",
          "20",
          "--no-namespace"
        ]);
        created = true;
      }
      const display = sf(["org", "display", "--target-org", org]).result;
      const apex = createApex({ sfJson: sf, org });
      const organization = apex.soql(
        "SELECT Id, OrganizationType, IsSandbox FROM Organization"
      )[0];
      orgInfo = {
        ...orgInfo,
        edition: organization.OrganizationType,
        instanceUrl: display.instanceUrl,
        sandbox: organization.IsSandbox,
        scratch: created || Boolean(display.devHubId),
        type:
          created || display.devHubId
            ? "scratch"
            : organization.IsSandbox
              ? "sandbox"
              : "production"
      };
      if (selected.some((scenario) => scenario.deploy)) {
        if (selected.length !== 1)
          throw new Error("Scenarios with custom deployment must run alone");
        await selected[0].deploy({
          sfJson: (args) => sf([...args, "--target-org", org]),
          root,
          env,
          org,
          orgInfo,
          packageId: options.package,
          upgradeFrom: options.upgradeFrom
        });
      } else {
        if (options.package || options.upgradeFrom)
          throw new Error(
            "Package flags require an install scenario; current scenarios validate source only"
          );
        sf([
          "project",
          "deploy",
          "start",
          "--target-org",
          org,
          "--source-dir",
          join(root, "sfdx-source/checkr"),
          "--source-dir",
          join(root, "sfdx-source/reference"),
          "--wait",
          "20"
        ]);
      }
      orgInfo.id = organization.Id;
    } catch (error) {
      initError = error;
    }

    for (const scenario of selected) {
      const summary = {
        scenario: scenario.name,
        startedAt,
        finishedAt: null,
        commit,
        dirty,
        packageVersion: options.package ?? null,
        org: Object.fromEntries(
          Object.entries(orgInfo).filter(([key]) => key !== "id")
        ),
        identities: [],
        outcome: "passed",
        checks: [],
        metrics: {}
      };
      const files = new Map();
      summaries.push(summary);
      artifacts.push(files);
      const users = new Map();
      const scopedSf = (args) =>
        sf(
          args.includes("--target-org") ? args : [...args, "--target-org", org]
        );
      const apex = createApex({ sfJson: sf, sfJsonAsync: sfAsync, org, users });
      const ctx = {
        sfJson: scopedSf,
        env,
        org,
        root,
        orgInfo,
        keep: options.keep,
        users,
        packageId: options.package,
        upgradeFrom: options.upgradeFrom,
        packageVersion: (version) => {
          summary.packageVersion = version;
        },
        ...apex,
        runAer: () => runAer(root),
        metrics: summary.metrics,
        artifact: (name, data) => {
          redact(data);
          files.set(name, data);
        },
        metric: (name, value) => {
          summary.metrics[name] = value;
        },
        check: (name, passed, detail = "") => {
          summary.checks.push({
            name,
            outcome: passed ? "passed" : "failed",
            detail
          });
          if (!passed) summary.outcome = "failed";
        }
      };
      let identityCleanup;
      let phase = "initialization";
      try {
        if (initError) throw initError;
        phase = "identities";
        const ensureUser = createIdentities({
          sfJson: sf,
          soql: apex.soql,
          org,
          orgId: orgInfo.id,
          users
        });
        ensureAdminPermset(ctx);
        identityCleanup = ensureUser.cleanup;
        for (const spec of scenario.identities ?? [])
          summary.identities.push(ensureUser(spec));
        for (phase of ["setup", "run", "verify"]) await scenario[phase](ctx);
      } catch (error) {
        summary.outcome = "error";
        summary.checks.push({
          name: phase,
          outcome: "failed",
          detail: error.message
        });
        files.set("scenario/error.json", {
          name: error.name,
          status: error.status,
          message: error.message,
          ...(error.command?.length ? { command: error.command } : {}),
          ...(error.detail && Object.keys(error.detail).length
            ? { detail: error.detail }
            : {})
        });
      }
      if (!options.keep && !initError && scenario.cleanup) {
        try {
          await scenario.cleanup(ctx);
        } catch (error) {
          summary.outcome = "error";
          summary.checks.push({
            name: "cleanup",
            outcome: "failed",
            detail: error.message
          });
        }
      }
      if (!options.keep && identityCleanup) {
        try {
          identityCleanup();
        } catch (error) {
          summary.outcome = "error";
          summary.checks.push({
            name: "identity cleanup",
            outcome: "failed",
            detail: error.message
          });
        }
      }
      summary.finishedAt = new Date().toISOString();
    }
  } finally {
    if (created && !options.keep) {
      try {
        sf(["org", "delete", "scratch", "--target-org", org, "--no-prompt"]);
      } catch (error) {
        for (const summary of summaries) {
          summary.outcome = "error";
          summary.checks.push({
            name: "Scratch org cleanup",
            outcome: "failed",
            detail: error.message
          });
        }
        log(`Scratch org cleanup failed; alias: ${org}`);
      }
    }
  }
  if (created && options.keep) log(`Kept scratch org alias: ${org}`);
  mkdirSync(evidenceRoot, { recursive: true });
  const date = startedAt.slice(0, 10);
  for (const [index, summary] of summaries.entries()) {
    const base = join(
      evidenceRoot,
      `${date}-${summary.scenario}-${commit.slice(0, 7)}`
    );
    let folder = base;
    for (let suffix = 2; ; suffix++) {
      try {
        mkdirSync(folder, { recursive: false });
        break;
      } catch (error) {
        if (error.code !== "EEXIST") throw error;
        folder = `${base}-${suffix}`;
      }
    }
    for (const [name, data] of artifacts[index])
      writeArtifact(folder, name, data, redact);
    writeArtifact(folder, "scenario/sf-calls.json", calls, redact);
    // Summaries stay complete, machine-readable JSON, independent of log limits.
    const safeSummary = redact(summary);
    writeFileSync(
      join(folder, "summary.json"),
      JSON.stringify(safeSummary, null, 2) + "\n"
    );
    writeFileSync(join(folder, "README.md"), renderSummary(safeSummary));
    updateCatalog(evidenceRoot, summary.scenario, folder);
    log(`${summary.scenario}: ${summary.outcome} — ${folder}`);
  }
  return summaries.every((summary) => summary.outcome === "passed") ? 0 : 1;
}

export async function main(args = process.argv.slice(2)) {
  try {
    const options = parseArgs(args);
    if (options.help) {
      console.log(
        "Usage: npm run org:evidence -- --scenario <name>[,<name>] (--org <alias> | --create-scratch) [--keep] [--package <04t>] [--upgrade-from <04t>]"
      );
      return 0;
    }
    return await runHarness(options);
  } catch (error) {
    console.error(createRedactor()(error.message));
    return 1;
  }
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
)
  process.exitCode = await main();
