import { existsSync, readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join, dirname, resolve, sep } from "node:path";

const sensitiveKey =
  /username|password|token|authurl|sfdxurl|authorization|clientsecret|privatekey/i;

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Evidence is published, so local paths are recorded relative to the repo
// root, and any other home-directory path becomes `<home>`.
export function createRedactor({
  root = process.cwd(),
  home = homedir()
} = {}) {
  const secrets = new Set();
  const rootPrefix = new RegExp(
    `(?:file://)?${escapeRegExp(resolve(root))}(?:/|(?=[\\s"'<>]|$))`,
    "g"
  );
  const homePrefix = new RegExp(
    `(?:file://)?${escapeRegExp(resolve(home))}(?=[/\\s"'<>]|$)`,
    "g"
  );
  function collect(value) {
    if (!value || typeof value !== "object") return;
    for (const [key, child] of Object.entries(value)) {
      if (
        sensitiveKey.test(key) &&
        typeof child === "string" &&
        child.length > 3
      ) {
        secrets.add(child);
      } else collect(child);
    }
  }
  function clean(value) {
    if (typeof value === "string") {
      let text = value;
      for (const secret of [...secrets].sort((a, b) => b.length - a.length)) {
        text = text.replaceAll(secret, "[REDACTED]");
      }
      return text
        .replace(/force:\/\/[^\s"'<>]+/gi, "[REDACTED]")
        .replace(/https?:\/\/[^\s"'<>]*(?:[?@])[^\s"'<>]*/gi, "[REDACTED URL]")
        .replace(/\b[^\s"'<>@]+@[^\s"'<>@]+\.[a-z0-9.-]+/gi, "[REDACTED USER]")
        .replace(
          /\b00D[a-zA-Z0-9]{12,15}![a-zA-Z0-9._!-]+/g,
          "[REDACTED TOKEN]"
        )
        .replace(/Bearer\s+[^\s"'<>]+/gi, "Bearer [REDACTED]")
        .replace(rootPrefix, "")
        .replace(homePrefix, "<home>")
        .replace(/(?:file:\/\/)?\/(?:home|Users)\/[^/\s"'<>]+/g, "<home>");
    }
    if (Array.isArray(value)) return value.map(clean);
    if (value && typeof value === "object") {
      return Object.fromEntries(
        Object.entries(value).map(([key, child]) => [
          key,
          sensitiveKey.test(key) ? "[REDACTED]" : clean(child)
        ])
      );
    }
    return value;
  }
  return (value) => {
    collect(value);
    return clean(value);
  };
}

export function trimLog(text, maxLines = 200, maxBytes = 256 * 1024) {
  const lines = String(text).split("\n").slice(-maxLines).join("\n");
  let tail = Buffer.from(lines).subarray(-maxBytes).toString("utf8");
  // A slice through a multibyte character must not exceed the byte limit.
  while (Buffer.byteLength(tail) > maxBytes) tail = tail.slice(1);
  return tail;
}

export function writeArtifact(folder, name, data, redact) {
  const target = resolve(folder, name);
  if (!target.startsWith(resolve(folder) + sep))
    throw new Error("Artifact path escapes evidence folder");
  const safe = redact(data);
  let text = typeof safe === "string" ? safe : JSON.stringify(safe, null, 2);
  const tail = trimLog(
    text,
    typeof safe === "string" ? 199 : Infinity,
    256 * 1024 - 1
  );
  if (tail !== text) {
    text =
      typeof safe === "string"
        ? tail
        : JSON.stringify(
            { truncated: true, tail: trimLog(text, 180, 32 * 1024) },
            null,
            2
          );
  }
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, text + "\n");
}

export function renderSummary(summary) {
  const checks = summary.checks.map(
    (check) => `- ${check.outcome}: ${check.name} — ${check.detail ?? ""}`
  );
  return [
    `# Org evidence: ${summary.scenario}`,
    "",
    `Outcome: **${summary.outcome}**`,
    "",
    `Started: ${summary.startedAt}`,
    `Finished: ${summary.finishedAt}`,
    `Commit: ${summary.commit}${summary.dirty ? " (dirty)" : ""}`,
    `Package version: ${summary.packageVersion ?? "source deploy"}`,
    "",
    "## Checks",
    "",
    ...(checks.length ? checks : ["No checks completed."]),
    "",
    "## Metrics",
    "",
    "```json",
    JSON.stringify(summary.metrics, null, 2),
    "```",
    ""
  ].join("\n");
}

// Replace only the matching catalog row, preserving documentation and other runs.
export function updateCatalog(root, scenario, folder) {
  const file = join(root, "README.md");
  if (!existsSync(file)) return;
  const content = readFileSync(file, "utf8");

  const lines = content.split("\n").map((line) => {
    const cells = line.split("|");
    if (cells[1]?.trim() !== `\`${scenario}\``) return line;
    cells[cells.length - 2] = ` [latest](${basename(folder)}/README.md) `;
    return cells.join("|");
  });
  writeFileSync(file, lines.join("\n"));
}
