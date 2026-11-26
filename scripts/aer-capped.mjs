#!/usr/bin/env node
/**
 * Run the CI no-org AER Apex tier within the 100-test cap.
 *
 * The AER license does not cover CI, so AER stops after 100 tests there and
 * exits non-zero. CI runs the most recently added `sfdx-source/checkr` test
 * classes that fit under the cap and lists the classes it left out. The local
 * and aloop gate (scripts/gate.mjs) runs the full suite, both packages, under
 * the developer license.
 *
 * Usage: node scripts/aer-capped.mjs [--print-flags]
 *   --print-flags  print the AER flags instead of running AER (CI passes them
 *                  to the aer-dist action).
 *
 * AER_TEST_CAP overrides the cap (default 100).
 */
import { execFileSync } from "node:child_process";
import { readdirSync } from "node:fs";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";

export const SOURCE = "sfdx-source/checkr";
export const BASE_FLAGS = ["-p", "CKR_Admin"];

/** Counts test methods per class from `aer test --dry-run` output. */
export function countTestsPerClass(dryRunOutput) {
  const perClass = new Map();
  for (const line of dryRunOutput.split("\n")) {
    const name = line.match(/^\s+(\w+)\.\w+$/)?.[1];
    if (name) perClass.set(name, (perClass.get(name) ?? 0) + 1);
  }
  return perClass;
}

/**
 * Picks whole classes, newest first-added first (ties by name), until the next
 * class would pass the cap. Entries are `{ name, count, file, added }`.
 */
export function selectWithinCap(entries, cap) {
  const ranked = [...entries].sort(
    (a, b) => b.added - a.added || a.name.localeCompare(b.name)
  );
  let total = 0;
  const selected = [];
  const skipped = [];
  for (const entry of ranked) {
    if (total + entry.count <= cap) {
      selected.push(entry);
      total += entry.count;
    } else skipped.push(entry);
  }
  return { selected, skipped, total };
}

/** AER flags for a selection: no `--filter-path` when nothing was skipped. */
export function flagsFor({ selected, skipped }) {
  return skipped.length
    ? [
        ...BASE_FLAGS,
        ...selected.flatMap((entry) => ["--filter-path", entry.file])
      ]
    : [...BASE_FLAGS];
}

function addedAt(file) {
  // A class with no commit yet (new in this branch) counts as newest.
  // --follow keeps the original add date across moves between folders.
  const out = execFileSync(
    "git",
    ["log", "--follow", "--diff-filter=A", "--format=%ct", "-1", "--", file],
    { encoding: "utf8" }
  ).trim();
  return out ? Number(out) : Number.POSITIVE_INFINITY;
}

function main() {
  const cap = Number(process.env.AER_TEST_CAP ?? 100);
  const printFlags = process.argv.includes("--print-flags");
  const perClass = countTestsPerClass(
    execFileSync("aer", ["test", SOURCE, ...BASE_FLAGS, "--dry-run"], {
      encoding: "utf8"
    })
  );
  const classFiles = new Map(
    readdirSync(SOURCE, { recursive: true })
      .filter((file) => file.endsWith(".cls"))
      .map((file) => [basename(file, ".cls"), join(SOURCE, file)])
  );
  const entries = [...perClass].map(([name, count]) => {
    const file = classFiles.get(name);
    if (!file) throw new Error(`Test class not found: ${name}.cls`);
    return { name, count, file, added: addedAt(file) };
  });
  const selection = selectWithinCap(entries, cap);
  const all = entries.reduce((sum, entry) => sum + entry.count, 0);
  if (selection.skipped.length) {
    console.warn(
      `AER CI cap: running ${selection.total} of ${all} tests. ` +
        `Skipped (oldest first-added): ${selection.skipped
          .map((entry) => `${entry.name} (${entry.count})`)
          .join(", ")}`
    );
  }
  const flags = flagsFor(selection);
  if (printFlags) process.stdout.write(flags.join(" ") + "\n");
  else execFileSync("aer", ["test", SOURCE, ...flags], { stdio: "inherit" });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
