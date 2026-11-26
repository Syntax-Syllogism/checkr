import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  assertCleanTree,
  assertOnMaster,
  main,
  parseArgs,
  parseVersion,
  releaseRecord,
  versionAlias
} from "../create-beta.mjs";

const HEAD = "abcdef0123456789abcdef0123456789abcdef01";
const SUBSCRIBER = "04t000000000001AAA";

function fakeRun({ porcelain = "", containing = "  origin/master", sf = {} }) {
  const calls = [];
  const run = (bin, args) => {
    calls.push([bin, ...args]);
    if (bin === "git") {
      if (args[0] === "status") return porcelain;
      if (args[0] === "rev-parse") return HEAD;
      if (args[0] === "branch") return containing;
      return "";
    }
    if (bin === "sf") {
      const key = args.slice(0, 3).join(" ");
      if (!(key in sf)) throw new Error(`unexpected sf ${key}`);
      return JSON.stringify(sf[key]);
    }
    return "";
  };
  return { run, calls };
}

function temp(t) {
  const root = mkdtempSync(join(tmpdir(), "checkr-release-"));
  t.after(() => rmSync(root, { force: true, recursive: true }));
  return root;
}

test("arguments accept only the documented flags", () => {
  assert.deepEqual(parseArgs([]), {
    allowBranch: false,
    branch: true,
    dryRun: false
  });
  assert.deepEqual(parseArgs(["--allow-branch", "--no-branch", "--dry-run"]), {
    allowBranch: true,
    branch: false,
    dryRun: true
  });
  assert.throws(() => parseArgs(["--promote"]), /Unknown argument/);
});

test("clean-tree check rejects any porcelain entry", () => {
  assert.doesNotThrow(() => assertCleanTree(""));
  assert.doesNotThrow(() => assertCleanTree("\n"));
  assert.throws(() => assertCleanTree(" M README.md\n"), /1 change/);
  assert.throws(() => assertCleanTree("?? new.txt\n M a\n"), /2 change/);
});

test("HEAD must be on origin/master unless --allow-branch", () => {
  const head = "abcdef0123456789";
  assert.doesNotThrow(() =>
    assertOnMaster({
      head,
      containing: "  origin/HEAD -> origin/master\n  origin/master"
    })
  );
  assert.throws(
    () => assertOnMaster({ head, containing: "  origin/feature" }),
    /abcdef0 is not on origin\/master/
  );
  assert.throws(
    () => assertOnMaster({ head, containing: "  origin/master-old" }),
    /not on origin\/master/
  );
  assert.doesNotThrow(() =>
    assertOnMaster({ head, containing: "", allowBranch: true })
  );
});

test("versions parse four numeric parts and map to sf aliases", () => {
  assert.deepEqual(parseVersion("0.1.0.2"), {
    major: 0,
    minor: 1,
    patch: 0,
    build: 2
  });
  assert.equal(versionAlias("0.1.0.1"), "checkr@0.1.0-1");
  assert.equal(versionAlias("0.1.0.12"), "checkr@0.1.0-12");
  for (const bad of ["0.1.0", "0.1.0.NEXT", "", undefined, "1.2.3.4.5"])
    assert.throws(() => parseVersion(bad), /Unexpected package version/);
});

test("release record keeps the 04t, version, coverage and commit", () => {
  const record = releaseRecord(
    {
      Id: "05i000000000001AAA",
      Version: "0.1.0.1",
      SubscriberPackageVersionId: SUBSCRIBER,
      Tag: "abc",
      IsReleased: false,
      CodeCoverage: { apexCodeCoveragePercentage: 94 },
      HasPassedCodeCoverageCheck: true,
      ValidationSkipped: false
    },
    { commit: "abc", createdAt: "2026-10-20T00:00:00.000Z" }
  );
  assert.equal(record.package, "checkr");
  assert.equal(record.subscriberPackageVersionId, SUBSCRIBER);
  assert.equal(record.alias, "checkr@0.1.0-1");
  assert.equal(record.codeCoverage, 94);
  assert.equal(record.hasPassedCodeCoverageCheck, true);
  assert.equal(record.commit, "abc");
  assert.equal(record.released, false);
  assert.equal(
    record.installUrl,
    `https://test.salesforce.com/packaging/installPackage.apexp?p0=${SUBSCRIBER}`
  );
  assert.equal(
    releaseRecord(
      {
        Version: "0.1.0.1",
        SubscriberPackageVersionId: "04t000000000002AAA",
        CodeCoverage: 81
      },
      { commit: "x", createdAt: "t" }
    ).codeCoverage,
    81
  );
  assert.equal(
    releaseRecord(
      {
        Version: "0.1.0.1",
        SubscriberPackageVersionId: "04t000000000002AAA",
        CodeCoverage: null
      },
      { commit: "x", createdAt: "t" }
    ).codeCoverage,
    null
  );
  assert.throws(
    () =>
      releaseRecord({ Version: "0.1.0.2" }, { commit: "x", createdAt: "t" }),
    /SubscriberPackageVersionId/
  );
});

test("dry run checks git and prints the plan without calling sf", async () => {
  const { run, calls } = fakeRun({});
  const lines = [];
  const code = await main(["--dry-run"], {
    root: "/nowhere",
    env: { DEVHUB_ALIAS: "hub" },
    log: (line) => lines.push(line),
    run
  });
  assert.equal(code, 0);
  assert.ok(calls.every(([bin]) => bin === "git"));
  const output = lines.join("\n");
  assert.match(
    output,
    /sf package version create --package checkr --installation-key-bypass --code-coverage --tag abcdef0123456789abcdef0123456789abcdef01 --wait 60 --target-dev-hub hub --json/
  );
  assert.match(output, /chore\/package-<version>/);
});

test("dirty tree or a non-master HEAD stops before any sf call", async () => {
  const dirty = fakeRun({ porcelain: " M README.md" });
  await assert.rejects(
    main([], { root: "/nowhere", log: () => {}, run: dirty.run }),
    /not clean/
  );
  const branch = fakeRun({ containing: "  origin/feature" });
  await assert.rejects(
    main([], { root: "/nowhere", log: () => {}, run: branch.run }),
    /not on origin\/master/
  );
  for (const { calls } of [dirty, branch])
    assert.ok(calls.every(([bin]) => bin === "git"));
});

test("a successful create writes version.json and commits on a release branch", async (t) => {
  const root = temp(t);
  const { run, calls } = fakeRun({
    sf: {
      "package version create": {
        status: 0,
        result: { Status: "Success", SubscriberPackageVersionId: SUBSCRIBER }
      },
      "package version report": {
        status: 0,
        result: {
          Id: "05i000000000001AAA",
          Version: "0.1.0.1",
          SubscriberPackageVersionId: SUBSCRIBER,
          CodeCoverage: { apexCodeCoveragePercentage: 94 },
          HasPassedCodeCoverageCheck: true
        }
      }
    }
  });
  const code = await main([], {
    root,
    log: () => {},
    run,
    now: () => new Date("2026-10-20T00:00:00.000Z")
  });
  assert.equal(code, 0);
  const record = JSON.parse(
    readFileSync(
      join(root, "docs/evidence/releases/0.1.0.1/version.json"),
      "utf8"
    )
  );
  assert.equal(record.alias, "checkr@0.1.0-1");
  assert.equal(record.commit, HEAD);
  assert.equal(record.createdAt, "2026-10-20T00:00:00.000Z");
  const create = calls.find((call) => call[2] === "version");
  assert.deepEqual(create.slice(-3), ["--target-dev-hub", "devHub", "--json"]);
  assert.ok(
    calls.some(
      (call) => call.join(" ") === "git switch -c chore/package-0.1.0.1"
    )
  );
  assert.ok(calls.some((call) => call[0] === "git" && call[1] === "commit"));
  assert.ok(!calls.some((call) => call.includes("push")));
});

test("a failed create or sf error fails without writing evidence", async (t) => {
  const root = temp(t);
  const failed = fakeRun({
    sf: {
      "package version create": {
        status: 0,
        result: { Status: "Error", Error: ["coverage below 75%"] }
      }
    }
  });
  await assert.rejects(
    main([], { root, log: () => {}, run: failed.run }),
    /did not succeed: Error coverage below 75%/
  );
  const error = fakeRun({
    sf: {
      "package version create": { status: 1, message: "No Dev Hub" }
    }
  });
  await assert.rejects(
    main([], { root, log: () => {}, run: error.run }),
    /sf package version create: No Dev Hub/
  );
  assert.equal(existsSync(join(root, "docs/evidence/releases")), false);
});
