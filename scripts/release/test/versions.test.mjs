import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { assertVersionBumped } from "../create-beta.mjs";
import { main as record, addToUnreleased } from "../record-release.mjs";
import { checkState, nextVersions, readState } from "../versions.mjs";

const OLD = "04tOLD000000000AAA";
const NEW = "04tNEW000000000AAA";

function repo(t, { source = "0.1.2", pkg = "0.1.3" } = {}) {
  const root = mkdtempSync(join(tmpdir(), "checkr-versions-"));
  t.after(() => rmSync(root, { force: true, recursive: true }));
  const write = (file, text) => {
    mkdirSync(join(root, file, ".."), { recursive: true });
    writeFileSync(join(root, file), text);
  };
  write("package.json", JSON.stringify({ version: source }));
  write(
    "sfdx-project.json",
    JSON.stringify({
      packageDirectories: [
        {
          package: "checkr",
          versionNumber: `${pkg}.NEXT`,
          versionName: `ver ${pkg}`
        }
      ]
    })
  );
  const rec = (version, id, released) =>
    write(
      `docs/evidence/releases/${version}/version.json`,
      JSON.stringify({
        version,
        subscriberPackageVersionId: id,
        released,
        commit: "abcdef0123",
        codeCoverage: 94
      })
    );
  rec("0.1.2.1", OLD, true);
  rec("0.1.3.1", NEW, false);
  write(
    "README.md",
    `CheckR 0.1.2 is released. The current version is 0.1.2 (\`${OLD}\`).\n`
  );
  write("docs/installation.md", `The current\nversion is 0.1.2, \`${OLD}\`.\n`);
  write(
    "CHANGELOG.md",
    "# Changelog\n\n## [Unreleased]\n\n### Fixed\n\n- A fix.\n\n## [0.1.2] - 2026-11-26\n"
  );
  return root;
}

test("next versions", () => {
  assert.deepEqual(nextVersions("0.1.2"), {
    patch: "0.1.3",
    minor: "0.2.0",
    major: "1.0.0"
  });
});

test("a consistent tree between releases passes; --release needs the promotion", (t) => {
  const root = repo(t);
  assert.deepEqual(checkState(readState(root)), []);
  assert.equal(checkState(readState(root), { release: true }).length, 2);
});

test("drift is reported", (t) => {
  const root = repo(t, { pkg: "0.1.5" });
  assert.match(checkState(readState(root)).join("\n"), /versionNumber 0.1.5/);
  const bumped = repo(t, { source: "0.1.3" });
  assert.match(
    checkState(readState(bumped)).join("\n"),
    /CHANGELOG heading is 0.1.2/
  );
});

test("record-release updates docs, version.json, and the changelog; then --release passes", (t) => {
  const root = repo(t);
  record([NEW, "--no-verify"], { root, log: () => {} });
  const readme = readFileSync(join(root, "README.md"), "utf8");
  assert.match(
    readme,
    /CheckR 0\.1\.3 is released\. The current version is 0\.1\.3 \(`04tNEW/
  );
  assert.match(
    readFileSync(join(root, "docs/installation.md"), "utf8"),
    /version is 0\.1\.3, `04tNEW/
  );
  const json = JSON.parse(
    readFileSync(
      join(root, "docs/evidence/releases/0.1.3.1/version.json"),
      "utf8"
    )
  );
  assert.equal(json.released, true);
  assert.match(json.installUrl, /login\.salesforce\.com.*04tNEW/);
  assert.deepEqual(checkState(readState(root), { release: true }), []);
  assert.throws(
    () => record([NEW, "--no-verify"], { root, log: () => {} }),
    /already recorded/
  );
});

test("record-release refuses an unpromoted version", (t) => {
  const root = repo(t);
  const run = () =>
    JSON.stringify({ status: 0, result: { IsReleased: false } });
  assert.throws(
    () => record([NEW], { root, run, log: () => {} }),
    /not promoted/
  );
});

test("changelog entry goes under an existing Added heading", () => {
  const out = addToUnreleased(
    "## [Unreleased]\n\n### Added\n\n- x\n\n## [0.1.0]\n",
    "- new"
  );
  assert.equal(
    out,
    "## [Unreleased]\n\n### Added\n\n- new\n- x\n\n## [0.1.0]\n"
  );
});

test("create-beta refuses a versionNumber that is already promoted", (t) => {
  assert.throws(
    () => assertVersionBumped(repo(t, { pkg: "0.1.2" })),
    /already promoted/
  );
  assert.doesNotThrow(() => assertVersionBumped(repo(t)));
});
