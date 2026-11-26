#!/usr/bin/env node
/**
 * Checks that the version numbers CheckR records agree with each other.
 *
 *   npm run check:versions              # any time; part of npm test
 *   npm run check:versions -- --release # strict, just before `publish -b patch`
 *
 * Sources: package.json (source release, P), sfdx-project.json versionNumber
 * (package version being built, S), the newest promoted
 * docs/evidence/releases/<v>/version.json (R), the README and installation
 * `04t` and "current version" text, and the newest released CHANGELOG heading.
 *
 * Always: S is P or the next patch/minor/major of P; R is P or S; the README
 * and installation point at R; the newest CHANGELOG heading is P.
 * --release (before publishing source P+1): S and R are the next patch of P,
 * and the [Unreleased] changelog section names R's 04t.
 */
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const triple = (text) => {
  const match = /^(\d+)\.(\d+)\.(\d+)/.exec(String(text ?? ""));
  if (!match) throw new Error(`Not a version: ${text}`);
  return match.slice(1, 4).map(Number);
};
export const mmp = (text) => triple(text).join(".");
export const compare = (a, b) => {
  const [x, y] = [triple(a), triple(b)];
  for (let i = 0; i < 3; i += 1) if (x[i] !== y[i]) return x[i] - y[i];
  return 0;
};
export function nextVersions(version) {
  const [major, minor, patch] = triple(version);
  return {
    patch: `${major}.${minor}.${patch + 1}`,
    minor: `${major}.${minor + 1}.0`,
    major: `${major + 1}.0.0`
  };
}

const read = (root, file) => readFileSync(join(root, file), "utf8");

export function releaseRecords(root) {
  const dir = join(root, "docs/evidence/releases");
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => existsSync(join(dir, name, "version.json")))
    .map((name) =>
      JSON.parse(read(root, `docs/evidence/releases/${name}/version.json`))
    )
    .sort((a, b) => {
      const byVersion = compare(a.version, b.version);
      return (
        byVersion ||
        Number(a.version.split(".")[3]) - Number(b.version.split(".")[3])
      );
    });
}

export function latestReleased(root) {
  return releaseRecords(root)
    .filter((record) => record.released)
    .at(-1);
}

export function readState(root) {
  const project = JSON.parse(read(root, "sfdx-project.json"));
  const packaged = project.packageDirectories.find(
    (dir) => dir.package === "checkr"
  );
  const changelog = read(root, "CHANGELOG.md");
  const unreleased = /^## \[Unreleased\]\s*$([\s\S]*?)(?=^## \[)/m.exec(
    changelog
  );
  return {
    source: JSON.parse(read(root, "package.json")).version,
    packageVersion: mmp(packaged.versionNumber),
    versionName: packaged.versionName,
    released: latestReleased(root),
    changelogTop: /^## \[(\d+\.\d+\.\d+)\]/m.exec(changelog)?.[1],
    unreleased: unreleased?.[1] ?? "",
    docs: Object.fromEntries(
      ["README.md", "docs/installation.md"].map((file) => [
        file,
        read(root, file)
      ])
    )
  };
}

export function checkState(state, { release = false } = {}) {
  const errors = [];
  const { source, packageVersion, released } = state;
  const next = nextVersions(source);
  if (![source, ...Object.values(next)].includes(packageVersion))
    errors.push(
      `sfdx-project.json versionNumber ${packageVersion} must be ${source} or the next version after it`
    );
  if (state.versionName !== `ver ${packageVersion}`)
    errors.push(
      `sfdx-project.json versionName must be "ver ${packageVersion}"`
    );
  if (state.changelogTop !== source)
    errors.push(
      `newest CHANGELOG heading is ${state.changelogTop}, package.json is ${source}`
    );
  if (!released)
    errors.push("no promoted version.json under docs/evidence/releases");
  else {
    const releasedVersion = mmp(released.version);
    const id = released.subscriberPackageVersionId;
    if (![source, packageVersion].includes(releasedVersion))
      errors.push(
        `newest promoted package is ${releasedVersion}; it must match package.json (${source}) or sfdx-project.json (${packageVersion})`
      );
    for (const [file, text] of Object.entries(state.docs)) {
      const ids = new Set(text.match(/04t[A-Za-z0-9]{15}/g) ?? []);
      if (ids.size !== 1 || !ids.has(id))
        errors.push(
          `${file} must name only the promoted 04t ${id}, found ${[...ids].join(", ") || "none"}`
        );
      const current = /current\s+version\s+is\s+(\d+\.\d+\.\d+)/i.exec(
        text
      )?.[1];
      if (current !== releasedVersion)
        errors.push(
          `${file} says the current version is ${current}, expected ${releasedVersion}`
        );
    }
    if (release) {
      if (packageVersion !== next.patch || releasedVersion !== next.patch)
        errors.push(
          `--release: promote ${next.patch} first (sfdx-project.json ${packageVersion}, promoted ${releasedVersion})`
        );
      if (!state.unreleased.includes(id))
        errors.push(
          `--release: the [Unreleased] changelog section must name ${id}`
        );
    }
  }
  return errors;
}

export function main(
  args = process.argv.slice(2),
  {
    root = fileURLToPath(new URL("../../", import.meta.url)),
    log = console.log
  } = {}
) {
  const unknown = args.filter((arg) => arg !== "--release");
  if (unknown.length) throw new Error(`Unknown argument: ${unknown.join(" ")}`);
  const state = readState(root);
  const errors = checkState(state, { release: args.includes("--release") });
  if (errors.length) {
    for (const error of errors) log(`✗ ${error}`);
    return 1;
  }
  log(
    `✓ versions agree: source ${state.source}, package ${state.packageVersion}, promoted ${state.released.version} (${state.released.subscriberPackageVersionId})`
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
