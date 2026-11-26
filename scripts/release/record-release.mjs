#!/usr/bin/env node
/**
 * Records a promoted checkr package version everywhere it is named.
 *
 *   npm run release:record -- <04t> [--no-verify]
 *
 * - confirms with `sf package version report` that the version is released
 *   (--no-verify skips this; tests only);
 * - sets `released: true` and the production install URL in its version.json;
 * - points README.md and docs/installation.md at the new 04t and version;
 * - adds the version to the [Unreleased] section of CHANGELOG.md, so the next
 *   `publish -b patch` ships it under the matching source version.
 * It writes files only; review, commit, and open a PR.
 */
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { parseSfJson, versionAlias } from "./create-beta.mjs";
import { latestReleased, mmp, releaseRecords } from "./versions.mjs";

const loginUrl = (id) =>
  `https://login.salesforce.com/packaging/installPackage.apexp?p0=${id}`;

export function changelogEntry(record) {
  return [
    `- Promote package version ${mmp(record.version)} (\`${versionAlias(record.version)}\`).`,
    `  - Subscriber package version: \`${record.subscriberPackageVersionId}\` (built from`,
    `    \`${record.commit.slice(0, 7)}\`, ${record.codeCoverage}% code coverage).`,
    `  - Install link: <${loginUrl(record.subscriberPackageVersionId)}>`,
    "    (use `test.salesforce.com` for a sandbox)."
  ].join("\n");
}

export function addToUnreleased(changelog, entry) {
  const match = /^## \[Unreleased\]\s*\n/m.exec(changelog);
  if (!match) throw new Error("CHANGELOG.md has no [Unreleased] section");
  const start = match.index + match[0].length;
  const end = changelog.slice(start).search(/^## \[/m) + start;
  const section = changelog.slice(start, end);
  const added = /^### Added\s*\n\n/m.exec(section);
  const updated = added
    ? section.slice(0, added.index + added[0].length) +
      entry +
      "\n" +
      section.slice(added.index + added[0].length)
    : `\n### Added\n\n${entry}\n` + section;
  return (
    changelog.slice(0, start) +
    updated.replace(/^\n+/, "\n") +
    changelog.slice(end)
  );
}

export function pointDocsAt(text, previous, record) {
  const version = mmp(record.version);
  let out = text.replaceAll(
    previous.subscriberPackageVersionId,
    record.subscriberPackageVersionId
  );
  const old = mmp(previous.version).replaceAll(".", "\\.");
  out = out.replace(
    new RegExp(`(current\\s+version\\s+is\\s+)${old}\\b`, "gi"),
    `$1${version}`
  );
  out = out.replace(new RegExp(`(CheckR\\s+)${old}\\b`, "g"), `$1${version}`);
  return out;
}

export function main(
  args = process.argv.slice(2),
  {
    root = fileURLToPath(new URL("../../", import.meta.url)),
    log = console.log,
    run = (bin, binArgs) =>
      execFileSync(bin, binArgs, {
        cwd: root,
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"]
      }),
    env = process.env
  } = {}
) {
  const id = args.find((arg) => !arg.startsWith("--"));
  if (!id || !/^04t[A-Za-z0-9]{15}$/.test(id))
    throw new Error("Usage: npm run release:record -- <04t> [--no-verify]");
  const record = releaseRecords(root).find(
    (r) => r.subscriberPackageVersionId === id
  );
  if (!record)
    throw new Error(`No docs/evidence/releases/*/version.json for ${id}`);
  if (record.released)
    throw new Error(`${record.version} is already recorded as released`);
  const previous = latestReleased(root);

  if (!args.includes("--no-verify")) {
    const sfArgs = [
      "package",
      "version",
      "report",
      "--package",
      id,
      "--target-dev-hub",
      env.DEVHUB_ALIAS ?? "devHub",
      "--json"
    ];
    let stdout;
    try {
      stdout = run("sf", sfArgs);
    } catch (error) {
      stdout = error.stdout;
    }
    if (parseSfJson(sfArgs, stdout)?.IsReleased !== true)
      throw new Error(
        `${id} is not promoted; run sf package version promote first`
      );
  }

  const file = join(
    root,
    "docs/evidence/releases",
    record.version,
    "version.json"
  );
  writeFileSync(
    file,
    JSON.stringify(
      { ...record, released: true, installUrl: loginUrl(id) },
      null,
      2
    ) + "\n"
  );
  if (previous)
    for (const doc of ["README.md", "docs/installation.md"]) {
      const path = join(root, doc);
      writeFileSync(
        path,
        pointDocsAt(readFileSync(path, "utf8"), previous, record)
      );
    }
  const changelog = join(root, "CHANGELOG.md");
  writeFileSync(
    changelog,
    addToUnreleased(readFileSync(changelog, "utf8"), changelogEntry(record))
  );
  log(
    `Recorded ${record.version} (${id}) as released. Review, commit, and open a PR.`
  );
  return 0;
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(resolve(process.argv[1])).href
) {
  try {
    process.exitCode = main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
