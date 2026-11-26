import { readdirSync } from "node:fs";
import { basename, join } from "node:path";
import { compareTests } from "../lib/aer.mjs";
import { SfError } from "../lib/sf.mjs";

export const COVERAGE_TARGET = 85;
export const PACKAGE_COVERAGE_MINIMUM = 75;

// sf reports totalCovered; older payloads and fixtures carry totalUncovered.
function coveredLines(entry) {
  if (typeof entry.totalCovered === "number") return entry.totalCovered;
  if (typeof entry.totalUncovered === "number")
    return entry.totalLines - entry.totalUncovered;
  return null;
}

export function coverageSummary(result) {
  const classes = (result.coverage?.coverage ?? []).map((entry) => {
    const covered = coveredLines(entry);
    return {
      name: entry.name,
      coveredLines: covered,
      totalLines: entry.totalLines,
      percent:
        covered === null
          ? null
          : entry.totalLines
            ? (100 * covered) / entry.totalLines
            : 100
    };
  });
  const totalLines = classes.reduce((sum, entry) => sum + entry.totalLines, 0);
  const covered = classes.reduce(
    (sum, entry) => sum + (entry.coveredLines ?? 0),
    0
  );
  const reported = result.summary?.orgWideCoverage;
  const overall =
    reported == null
      ? totalLines
        ? (100 * covered) / totalLines
        : null
      : Number.parseFloat(reported);
  return { classes, overall: Number.isFinite(overall) ? overall : null };
}

// Apex class and trigger names that ship in the checkr package directory.
export function packageApexNames(root) {
  const names = new Set();
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) walk(path);
      else if (/\.(cls|trigger)$/.test(entry.name))
        names.add(basename(entry.name).replace(/\.(cls|trigger)$/, ""));
    }
  };
  walk(join(root, "sfdx-source/checkr"));
  return names;
}

// Package version creation measures only packaged Apex, so this excludes the
// reference samples and any unrelated org code from org-wide coverage.
export function packageCoverage(classes, names) {
  const packaged = classes.filter(
    (entry) => names.has(entry.name) && entry.coveredLines !== null
  );
  const totalLines = packaged.reduce((sum, entry) => sum + entry.totalLines, 0);
  if (!totalLines) return null;
  const covered = packaged.reduce((sum, entry) => sum + entry.coveredLines, 0);
  return Math.round((1000 * covered) / totalLines) / 10;
}

export default {
  name: "apex-local-tests",
  description:
    "Real-org local tests, coverage, and same-source AER comparison.",
  needsOrgTests: false,
  identities: [],
  async setup() {},
  async run(ctx) {
    const aer = ctx.runAer();
    ctx.artifact("aer-results.json", aer);
    ctx.metric(
      "aerTestsPassed",
      aer.tests.filter((test) => test.passed).length
    );
    ctx.metric(
      "aerTestsFailed",
      aer.tests.filter((test) => !test.passed).length
    );
    ctx.metric("aerTestsRan", aer.tests.length);
    ctx.check(
      "AER suite completed",
      aer.status === 0 && aer.tests.length > 0,
      `${aer.tests.length} tests; exit ${aer.status}`
    );
    let response;
    try {
      response = ctx.sfJson([
        "apex",
        "run",
        "test",
        "--test-level",
        "RunLocalTests",
        "--code-coverage",
        "--result-format",
        "json",
        "--wait",
        "30"
      ]);
    } catch (error) {
      if (error.payload) ctx.artifact("apex-results.json", error.payload);
      const result = error.payload?.result;
      // A completed test run uses a nonzero CLI exit when assertions fail.
      // Auth, timeout, and malformed-response failures still abort the scenario.
      if (
        !(error instanceof SfError) ||
        result?.summary?.outcome !== "Failed" ||
        !(Number(result.summary.failing) > 0) ||
        !(Number(result.summary.testsRan) > 0) ||
        !Array.isArray(result.tests) ||
        result.tests.length === 0
      )
        throw error;
      response = error.payload;
    }
    ctx.artifact("apex-results.json", response);
    const result = response.result;
    const coverage = coverageSummary(result);
    ctx.metric("testsPassed", result.summary?.passing ?? 0);
    ctx.metric("testsFailed", result.summary?.failing ?? 0);
    const differences = compareTests(result.tests ?? [], aer.tests);
    ctx.artifact("aer-comparison.json", {
      differences,
      orgCount: result.tests?.length ?? 0,
      aerCount: aer.tests.length
    });
    ctx.metric("aerDifferences", differences);
    // Differences are evidence, rather than a reason to suppress a real-org baseline.
    ctx.artifact("coverage-summary.json", coverage);
    ctx.metric("coveragePercent", coverage.overall);
    ctx.metric(
      "packageCoveragePercent",
      packageCoverage(coverage.classes, packageApexNames(ctx.root))
    );
    ctx.metric("testsRan", result.summary?.testsRan ?? 0);
    ctx.check(
      "Local Apex tests",
      result.summary?.outcome === "Passed" &&
        Number(result.summary?.testsRan) > 0,
      `${result.summary?.testsRan ?? 0} tests; ${result.summary?.outcome ?? "no outcome"}`
    );
  },
  async verify(ctx) {
    ctx.check(
      `Overall Apex coverage >= ${COVERAGE_TARGET}%`,
      ctx.metrics.coveragePercent !== null &&
        ctx.metrics.coveragePercent >= COVERAGE_TARGET,
      `${ctx.metrics.coveragePercent ?? "unavailable"}%`
    );
    ctx.check(
      `CheckR package Apex coverage >= ${PACKAGE_COVERAGE_MINIMUM}%`,
      ctx.metrics.packageCoveragePercent !== null &&
        ctx.metrics.packageCoveragePercent >= PACKAGE_COVERAGE_MINIMUM,
      `${ctx.metrics.packageCoveragePercent ?? "unavailable"}%`
    );
  }
};
