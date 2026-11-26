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
import { existsSync } from "node:fs";

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

// The pinned AER version. v1.6.23 passes the full suite at API 67.0 and counts
// System.runAs as a DML statement like a real org; see docs/testing.md. Warn
// when the local binary differs.
const pinned = "v1.6.23",
  local = localAer.match(/v[\d.]+/)?.[0];
if (local !== pinned) {
  console.warn(
    `WARNING: local aer is ${local} but the pinned version is ${pinned}; results may differ.`
  );
}
run("npm run test:apex");
