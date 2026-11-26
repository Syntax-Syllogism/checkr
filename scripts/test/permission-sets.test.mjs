import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { XMLParser } from "fast-xml-parser";

const directory = path.resolve("sfdx-source/checkr/main/user/permissionsets");
const parser = new XMLParser();
const list = (value) => (value == null ? [] : [value].flat());

function classAccess(name) {
  const set = parser.parse(
    readFileSync(path.join(directory, `${name}.permissionset-meta.xml`), "utf8")
  ).PermissionSet;
  return list(set.classAccesses)
    .filter((access) => access.enabled === true)
    .map((access) => access.apexClass)
    .sort();
}

test("CKR_User grants both checklist controllers", () => {
  assert.deepEqual(classAccess("CKR_User"), [
    "CKR_ChecklistCreateActionController",
    "CKR_ChecklistViewerController"
  ]);
});

// The viewer's edit flag follows parent-record access, so granting the viewer
// controller here would show read-only users edit controls that then fail.
// See docs/security.md before changing this.
test("CKR_ReadOnly grants no Apex class access", () => {
  assert.deepEqual(classAccess("CKR_ReadOnly"), []);
});
