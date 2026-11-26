import {
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { setTimeout } from "node:timers/promises";

export function soqlLiteral(value) {
  return (
    "'" + String(value).replaceAll("\\", "\\\\").replaceAll("'", "\\'") + "'"
  );
}

export function createApex({
  sfJson,
  sfJsonAsync,
  org,
  users = new Map(),
  sleep = setTimeout,
  now = Date.now
}) {
  function soql(query) {
    return sfJson(["data", "query", "--target-org", org, "--query", query])
      .result.records;
  }
  function runAnonymous(source, { asUser } = {}) {
    if (asUser && !users.has(asUser))
      throw new Error(`Unknown identity key: ${asUser}`);
    const dir = mkdtempSync(join(tmpdir(), "checkr-apex-"));
    try {
      const file = join(dir, "anonymous.apex");
      writeFileSync(
        file,
        existsSync(source) ? readFileSync(source, "utf8") : source,
        { mode: 0o600 }
      );
      const result = sfJson([
        "apex",
        "run",
        "--target-org",
        asUser ? users.get(asUser) : org,
        "--file",
        file
      ]);
      if (result.result.success !== true)
        throw new Error(
          result.result.exceptionMessage ?? "Anonymous Apex failed"
        );
      return result.result;
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }
  async function runAnonymousAsync(source, { asUser } = {}) {
    if (asUser && !users.has(asUser))
      throw new Error(`Unknown identity key: ${asUser}`);
    if (!sfJsonAsync) throw new Error("Asynchronous CLI is unavailable");
    const dir = mkdtempSync(join(tmpdir(), "checkr-apex-"));
    try {
      const file = join(dir, "anonymous.apex");
      writeFileSync(file, source, { mode: 0o600 });
      const result = await sfJsonAsync([
        "apex",
        "run",
        "--target-org",
        asUser ? users.get(asUser) : org,
        "--file",
        file
      ]);
      if (result.result.success !== true)
        throw new Error(
          result.result.exceptionMessage ?? "Anonymous Apex failed"
        );
      return result.result;
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }
  async function waitForAsync({ classNames, since, timeoutMs = 120000 }) {
    if (
      !classNames?.length ||
      !classNames.every((name) => /^[A-Za-z][A-Za-z0-9_]*$/.test(name))
    ) {
      throw new Error("classNames must contain Apex class names");
    }
    const timestamp = new Date(since).toISOString();
    if (!Number.isFinite(timeoutMs) || timeoutMs <= 0)
      throw new Error("timeoutMs must be positive");
    const deadline = now() + timeoutMs;
    for (;;) {
      const jobs = soql(
        `SELECT Id, Status, NumberOfErrors, ExtendedStatus FROM AsyncApexJob WHERE ApexClass.Name IN (${classNames.map(soqlLiteral).join(",")}) AND CreatedDate >= ${timestamp}`
      );
      if (
        !jobs.some((job) =>
          ["Queued", "Holding", "Preparing", "Processing"].includes(job.Status)
        )
      )
        return jobs;
      if (now() >= deadline)
        throw new Error("Timed out waiting for AsyncApexJob");
      await sleep(Math.min(1000, deadline - now()));
    }
  }
  return { soql, runAnonymous, runAnonymousAsync, waitForAsync };
}
