import assert from "node:assert/strict";
import { test } from "node:test";

import {
  countTestsPerClass,
  flagsFor,
  selectWithinCap
} from "../aer-capped.mjs";

const entry = (name, count, added) => ({
  name,
  count,
  added,
  file: `sfdx-source/checkr/test/${name}.cls`
});

test("counts test methods per class from dry-run output", () => {
  const counts = countTestsPerClass(
    [
      "Would run 3 tests:",
      "  A_Test.one",
      "  A_Test.two",
      "  B_Test.one",
      ""
    ].join("\n")
  );
  assert.deepEqual(
    [...counts],
    [
      ["A_Test", 2],
      ["B_Test", 1]
    ]
  );
});

test("runs everything without filters when the suite fits", () => {
  const selection = selectWithinCap(
    [entry("A", 60, 1), entry("B", 40, 2)],
    100
  );
  assert.equal(selection.total, 100);
  assert.deepEqual(selection.skipped, []);
  assert.deepEqual(flagsFor(selection), ["-p", "CKR_Admin"]);
});

test("keeps the newest classes and skips the oldest past the cap", () => {
  const selection = selectWithinCap(
    [entry("Old", 30, 1), entry("Mid", 50, 2), entry("New", 40, 3)],
    100
  );
  assert.deepEqual(
    selection.selected.map((e) => e.name),
    ["New", "Mid"]
  );
  assert.deepEqual(
    selection.skipped.map((e) => e.name),
    ["Old"]
  );
  assert.equal(selection.total, 90);
  assert.deepEqual(flagsFor(selection), [
    "-p",
    "CKR_Admin",
    "--filter-path",
    "sfdx-source/checkr/test/New.cls",
    "--filter-path",
    "sfdx-source/checkr/test/Mid.cls"
  ]);
});

test("still fits a smaller older class after skipping a large one", () => {
  const selection = selectWithinCap(
    [entry("Small", 5, 1), entry("Big", 30, 2), entry("New", 80, 3)],
    100
  );
  assert.deepEqual(
    selection.selected.map((e) => e.name),
    ["New", "Small"]
  );
  assert.deepEqual(
    selection.skipped.map((e) => e.name),
    ["Big"]
  );
});

test("treats uncommitted classes as newest and breaks ties by name", () => {
  const selection = selectWithinCap(
    [
      entry("Committed", 10, 5),
      entry("Zeta", 10, Number.POSITIVE_INFINITY),
      entry("Alpha", 10, Number.POSITIVE_INFINITY)
    ],
    20
  );
  assert.deepEqual(
    selection.selected.map((e) => e.name),
    ["Alpha", "Zeta"]
  );
});
