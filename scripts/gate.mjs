#!/usr/bin/env node
/**
 * Local verification gate.
 *
 * A fresh git worktree has no `node_modules`, so
 * the gate must install dependencies before it can run the no-org checks. This
 * shim: (1) runs `npm ci` from the committed lockfile when `node_modules` is
 * absent, (2) runs the full local suite with `npm test` (including prettier,
 * afmt, SLDS, markdownlint, Jest in both modes, and metadata/doc/harness checks),
 * (3) runs Salesforce Code Analyzer when installed, and (4) runs the no-org Apex tier with AER, matching CI.
 *
 * It must never depend on org connectivity. Real-org checks run through the explicit org evidence harness.
 */
import { execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";

function run(cmd) {
  process.stdout.write(`\n$ ${cmd}\n`);
  execSync(cmd, { stdio: "inherit" });
}

// `sf project retrieve` drops org metadata here and .gitignore hides it. Warn
// rather than fail so a local retrieve does not break the gate.
if (existsSync("sfdx-source/checkr/main/default")) {
  console.warn(
    "WARNING: sfdx-source/checkr/main/default exists (ignored retrieve output). Delete it so it is not deployed with the package."
  );
}

if (!existsSync("node_modules")) {
  run("npm ci --no-audit --no-fund");
}
run("npm test");
run("npm run analyze -- --if-installed");

let localAer;
try {
  localAer = execSync("aer --version", { encoding: "utf8" });
  process.stdout.write(localAer);
} catch {
  console.error(
    "AER is required for the no-org Apex gate. Install aer and ensure it is on PATH."
  );
  process.exit(1);
}

// CI pins the AER binary via the aer-dist action's `version` input. Warn when
// the local binary differs so a local pass means the same thing as a CI pass.
const pinned = readFileSync(".github/workflows/ci.yml", "utf8").match(
    /aer-dist@[^\n]*\n(?:\s+[^\n]*\n)*?\s+version:\s*(v[\d.]+)/
  )?.[1],
  local = localAer.match(/v[\d.]+/)?.[0];
if (pinned && local !== pinned) {
  console.warn(
    `WARNING: local aer is ${local} but CI pins ${pinned}; results may differ.`
  );
}
run("npm run test:apex");
