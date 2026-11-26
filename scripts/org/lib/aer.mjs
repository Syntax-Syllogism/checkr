import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

export function runAer(root, execute = spawnSync) {
  const dir = mkdtempSync(join(tmpdir(), "checkr-aer-"));
  const file = join(dir, "results.jsonl");
  try {
    const result = execute(
      "aer",
      ["test", "sfdx-source/checkr", "-p", "CKR_Admin", `--json=${file}`],
      { cwd: root, encoding: "utf8", maxBuffer: 32 * 1024 * 1024 }
    );
    const tests = existsSync(file)
      ? readFileSync(file, "utf8")
          .trim()
          .split("\n")
          .filter(Boolean)
          .map(JSON.parse)
      : [];
    return {
      status: result.status,
      tests,
      stdout: result.stdout ?? "",
      stderr: result.stderr ?? "",
      error: result.error?.message
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

export function compareTests(orgTests, aerTests) {
  const failureMessages = new Map();
  for (const test of orgTests) {
    if (test.Outcome !== "Pass" && test.Message)
      failureMessages.set(`${test.ApexClass?.Name}.${test.MethodName}`, {
        orgMessage: String(test.Message).slice(0, 500)
      });
  }
  for (const test of aerTests) {
    if (!test.passed && test.message)
      failureMessages.set(test.testName, {
        ...failureMessages.get(test.testName),
        aerMessage: String(test.message).slice(0, 500)
      });
  }
  const org = new Map(
    orgTests.map((test) => [
      `${test.ApexClass?.Name}.${test.MethodName}`,
      test.Outcome === "Pass"
    ])
  );
  const aer = new Map(aerTests.map((test) => [test.testName, test.passed]));
  return [...new Set([...org.keys(), ...aer.keys()])]
    .sort()
    .filter((name) => org.get(name) !== aer.get(name))
    .map((name) => ({
      name,
      org: org.get(name) ?? "missing",
      aer: aer.get(name) ?? "missing",
      ...failureMessages.get(name)
    }));
}
