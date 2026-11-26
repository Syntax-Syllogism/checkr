// Keeps the system-mode table in docs/architecture.md honest: every production
// class that uses a system-mode marker must have a row, every row must still
// use a marker, and every covering test class must exist.
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";

const classesRoot = path.resolve("sfdx-source/checkr/main/classes");
const testSourceRoots = ["sfdx-source/checkr", "sfdx-source/reference"].map(
  (root) => path.resolve(root)
);
const architecture = readFileSync(path.resolve("docs/architecture.md"), "utf8");

const marker =
  /\bSYSTEM_MODE\b|\bquerySystemModeWithBinds\b|\bsystemDmlGateway\s*\(|\bCKR_ISystemDmlGateway\b|\bwithout\s+sharing\b/i;

function walk(directory, suffix) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) return walk(full, suffix);
    return entry.name.endsWith(suffix) ? [full] : [];
  });
}

// Comments may mention a marker without using it.
function stripComments(source) {
  return source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/^\s*\/\/.*$/gm, "");
}

function usesSystemMode(source) {
  return marker.test(stripComments(source));
}

function markedClasses() {
  return walk(classesRoot, ".cls")
    .filter((file) => usesSystemMode(readFileSync(file, "utf8")))
    .map((file) => path.basename(file, ".cls"))
    .sort();
}

function tableRows() {
  const section = architecture.split(/^### System-mode sites$/m)[1];
  assert.ok(
    section,
    "docs/architecture.md has no '### System-mode sites' table"
  );
  const body = section.split(/^#{2,3} /m)[0];
  return body
    .split("\n")
    .filter((line) => /^\|\s*`CKR_/.test(line))
    .map((line) => {
      const cells = line.split("|").map((cell) => cell.trim());
      return { className: cells[1].replaceAll("`", ""), tests: cells[4] };
    });
}

test("marker detection sees real uses and ignores comments", () => {
  assert.ok(usesSystemMode("[SELECT Id FROM Account WITH SYSTEM_MODE]"));
  assert.ok(usesSystemMode("public without sharing class X {}"));
  assert.ok(usesSystemMode("systemDmlGateway().doInsert(rows, true);"));
  assert.ok(!usesSystemMode("// querySystemModeWithBinds is documented\n"));
  assert.ok(!usesSystemMode("/* WITH SYSTEM_MODE */ public class X {}"));
  assert.ok(!usesSystemMode("public inherited sharing class X {}"));
});

test("every system-mode class is listed in docs/architecture.md", () => {
  const listed = new Set(tableRows().map((row) => row.className));
  const missing = markedClasses().filter((name) => !listed.has(name));
  assert.deepEqual(
    missing,
    [],
    `Add these system-mode classes to the docs/architecture.md table: ${missing.join(", ")}`
  );
});

test("every listed class still uses a system-mode marker", () => {
  const marked = new Set(markedClasses());
  const stale = tableRows()
    .map((row) => row.className)
    .filter((name) => !marked.has(name));
  assert.deepEqual(
    stale,
    [],
    `Remove these rows from the docs/architecture.md table: ${stale.join(", ")}`
  );
});

test("every covering test class named in the table exists", () => {
  const testClasses = new Set(
    testSourceRoots
      .flatMap((root) => walk(root, ".cls"))
      .map((file) => path.basename(file, ".cls"))
  );
  const named = tableRows().flatMap((row) =>
    [...row.tests.matchAll(/`(CKR_\w+)`/g)].map((match) => match[1])
  );
  assert.ok(named.length > 0, "the table names no covering tests");
  const unknown = named.filter((name) => !testClasses.has(name));
  assert.deepEqual(unknown, [], `Unknown test classes: ${unknown.join(", ")}`);
});
