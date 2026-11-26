#!/usr/bin/env node
/**
 * Creates a beta (unpromoted) checkr package version from a clean commit on
 * origin/master and records it under docs/evidence/releases/<version>/.
 *
 *   npm run release:beta -- [--allow-branch] [--no-branch] [--dry-run]
 *
 * - DEVHUB_ALIAS selects the Dev Hub (default `devHub`).
 * - `sf package version create` adds a packageAliases entry to
 *   sfdx-project.json. The script commits that and version.json on a new
 *   `chore/package-<version>` branch; it never pushes or promotes.
 * - --allow-branch permits a HEAD that is not on origin/master (testing only).
 * - --no-branch leaves the changes uncommitted.
 * - --dry-run runs the git checks and prints the sf commands without calling
 *   the Dev Hub.
 */
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { latestReleased, mmp } from "./versions.mjs";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const PACKAGE = "checkr";
const USAGE =
  "Usage: npm run release:beta -- [--allow-branch] [--no-branch] [--dry-run]";

export function parseArgs(args) {
  const options = { allowBranch: false, branch: true, dryRun: false };
  for (const arg of args) {
    if (arg === "--allow-branch") options.allowBranch = true;
    else if (arg === "--no-branch") options.branch = false;
    else if (arg === "--dry-run") options.dryRun = true;
    else if (arg === "--help") options.help = true;
    else throw new Error(`Unknown argument: ${arg}`);
  }
  return options;
}

// `git status --porcelain` output: any line means the tree is not clean.
export function assertCleanTree(porcelain) {
  const dirty = porcelain
    .split("\n")
    .map((line) => line.trimEnd())
    .filter(Boolean);
  if (dirty.length)
    throw new Error(
      `Working tree is not clean (${dirty.length} change(s)); commit or stash first`
    );
}

export function assertOnMaster({ head, containing, allowBranch }) {
  if (allowBranch) return;
  if (!containing.split("\n").some((line) => line.trim() === "origin/master"))
    throw new Error(
      `HEAD ${head.slice(0, 7)} is not on origin/master; fetch, check out master, or pass --allow-branch`
    );
}

// "0.1.0.2" -> { major: 0, minor: 1, patch: 0, build: 2 }
// A promoted major.minor.patch can't take another promoted build, so a beta
// of it could never ship: bump versionNumber in sfdx-project.json first.
export function assertVersionBumped(root) {
  const projectFile = join(root, "sfdx-project.json");
  if (!existsSync(projectFile)) return;
  const project = JSON.parse(readFileSync(projectFile, "utf8"));
  const packaged = project.packageDirectories?.find(
    (dir) => dir.package === PACKAGE
  );
  const released = latestReleased(root);
  if (
    packaged &&
    released &&
    mmp(packaged.versionNumber) === mmp(released.version)
  )
    throw new Error(
      `${mmp(released.version)} is already promoted; bump versionNumber and versionName in sfdx-project.json first`
    );
}

export function parseVersion(version) {
  const match = /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/.exec(String(version ?? ""));
  if (!match) throw new Error(`Unexpected package version: ${version}`);
  const [major, minor, patch, build] = match.slice(1).map(Number);
  return { major, minor, patch, build };
}

// The alias sf writes to packageAliases, e.g. checkr@0.1.0-1.
export function versionAlias(version) {
  const { major, minor, patch, build } = parseVersion(version);
  return `${PACKAGE}@${major}.${minor}.${patch}-${build}`;
}

export function createArgs({ commit, devHub }) {
  return [
    "package",
    "version",
    "create",
    "--package",
    PACKAGE,
    "--installation-key-bypass",
    "--code-coverage",
    "--tag",
    commit,
    "--wait",
    "60",
    "--target-dev-hub",
    devHub
  ];
}

export function reportArgs({ subscriberId, devHub }) {
  return [
    "package",
    "version",
    "report",
    "--package",
    subscriberId,
    "--verbose",
    "--target-dev-hub",
    devHub
  ];
}

export function releaseRecord(report, { commit, createdAt }) {
  const version = report.Version;
  parseVersion(version);
  if (!/^04t/.test(report.SubscriberPackageVersionId ?? ""))
    throw new Error("Version report has no SubscriberPackageVersionId");
  return {
    package: PACKAGE,
    version,
    subscriberPackageVersionId: report.SubscriberPackageVersionId,
    packageVersionId: report.Id ?? null,
    alias: versionAlias(version),
    commit,
    tag: report.Tag ?? null,
    createdAt,
    released: Boolean(report.IsReleased),
    codeCoverage:
      typeof report.CodeCoverage === "number"
        ? report.CodeCoverage
        : (report.CodeCoverage?.apexCodeCoveragePercentage ?? null),
    hasPassedCodeCoverageCheck: report.HasPassedCodeCoverageCheck ?? null,
    validationSkipped: report.ValidationSkipped ?? null,
    installUrl: `https://test.salesforce.com/packaging/installPackage.apexp?p0=${report.SubscriberPackageVersionId}`
  };
}

function execute(bin, args, root) {
  return execFileSync(bin, args, {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    stdio: ["ignore", "pipe", "pipe"]
  }).trim();
}

export function parseSfJson(args, stdout) {
  let payload;
  try {
    payload = JSON.parse(String(stdout));
  } catch {
    throw new Error(`sf ${args.slice(0, 3).join(" ")}: no JSON output`);
  }
  if (payload.status !== 0)
    throw new Error(
      `sf ${args.slice(0, 3).join(" ")}: ${payload.message ?? payload.name}`
    );
  return payload.result;
}

export async function main(
  args = process.argv.slice(2),
  {
    root = fileURLToPath(new URL("../../", import.meta.url)),
    env = process.env,
    log = console.log,
    run = execute,
    now = () => new Date()
  } = {}
) {
  const options = parseArgs(args);
  if (options.help) {
    log(USAGE);
    return 0;
  }
  const git = (gitArgs) => run("git", gitArgs, root);
  const sfJson = (sfArgs) => {
    let stdout;
    try {
      stdout = run("sf", [...sfArgs, "--json"], root);
    } catch (error) {
      stdout = error.stdout;
    }
    return parseSfJson(sfArgs, stdout);
  };
  const devHub = env.DEVHUB_ALIAS ?? "devHub";

  assertCleanTree(git(["status", "--porcelain"]));
  assertVersionBumped(root);
  git(["fetch", "--quiet", "origin", "master"]);
  const commit = git(["rev-parse", "HEAD"]);
  assertOnMaster({
    head: commit,
    containing: git(["branch", "-r", "--contains", commit]),
    allowBranch: options.allowBranch
  });

  if (options.dryRun) {
    log(`Dry run: would create ${PACKAGE} beta from ${commit.slice(0, 7)}:`);
    log(`  sf ${createArgs({ commit, devHub }).join(" ")} --json`);
    log(
      `  sf ${reportArgs({ subscriberId: "<04t>", devHub }).join(" ")} --json`
    );
    log("  write docs/evidence/releases/<version>/version.json");
    if (options.branch)
      log(
        "  commit sfdx-project.json and the evidence on chore/package-<version>"
      );
    return 0;
  }

  log(`Creating ${PACKAGE} beta from ${commit.slice(0, 7)} in ${devHub}...`);
  const created = sfJson(createArgs({ commit, devHub }));
  const subscriberId = created?.SubscriberPackageVersionId;
  if (created?.Status !== "Success" || !subscriberId)
    throw new Error(
      `Package version create did not succeed: ${created?.Status} ${(created?.Error ?? []).join("; ")}`
    );

  const report = sfJson(reportArgs({ subscriberId, devHub }));
  const record = releaseRecord(report, {
    commit,
    createdAt: now().toISOString()
  });
  const folder = join(root, "docs/evidence/releases", record.version);
  mkdirSync(folder, { recursive: true });
  writeFileSync(
    join(folder, "version.json"),
    JSON.stringify(record, null, 2) + "\n"
  );
  run(
    "npx",
    ["prettier", "--write", "sfdx-project.json", join(folder, "version.json")],
    root
  );
  log(
    `Created ${record.version} (${record.subscriberPackageVersionId}); coverage ${record.codeCoverage}%, passed check: ${record.hasPassedCodeCoverageCheck}`
  );

  if (options.branch) {
    const branch = `chore/package-${record.version}`;
    git(["switch", "-c", branch]);
    git(["add", "sfdx-project.json", folder]);
    git([
      "commit",
      "--no-verify",
      "-m",
      `chore(release): record beta ${record.version} (${record.subscriberPackageVersionId})`
    ]);
    log(`Committed on ${branch}; push it and open a PR.`);
  }
  return 0;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    process.exitCode = await main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
