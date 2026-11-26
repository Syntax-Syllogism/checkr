---
title: "Packaging and releases"
---

How the `checkr` package is built and versioned, and what a version needs
before it is promoted. Admins installing CheckR want
[installation](installation.md). Source snapshots are described in
[release](release.md).

## The package

- **Type:** unlocked second-generation package (2GP) named `checkr`, owned by
  the maintainers' Dev Hub. Its `0Ho` ID is the `checkr` entry in
  `packageAliases` in `sfdx-project.json`.
- **Contents:** everything under `sfdx-source/checkr`, the default package
  directory, including `@IsTest` classes.
- **Not packaged:** `sfdx-source/reference` (the Account trigger shim, smoke
  seeds, and `*IT` integration tests). It is a second, unpackaged directory
  with no `package` key. Subscribers write their own trigger shims from
  [installation](installation.md#enable-an-object).

The package was created once, by hand:

```bash
sf package create --name checkr --package-type Unlocked \
  --path sfdx-source/checkr --no-namespace --json
```

### No namespace

CheckR has no namespace, so subscriber code calls `CKR_ChecklistTriggerGateway`
and queries `CKR_` objects without a prefix, and the package can be developed
and tested in any org. The cost is that nothing reserves CheckR's API names in a
subscriber org. The `CKR_` prefix stands in for a namespace:

- every packaged API name and DeveloperName starts with `CKR_` (LWCs use `ckr`);
- names are `PascalCase` after the prefix;
- never use `CKR_` for subscriber-owned metadata such as trigger shims and their
  tests, so they can't collide with a later package version.

A namespace can't be added to an existing package. Moving to one later means a
new package and a data migration.

## Versions

- `versionNumber` in `sfdx-project.json` is `major.minor.patch.NEXT`. Each
  `sf package version create` takes the next build number, so betas of 0.1.0
  are `0.1.0.1`, `0.1.0.2`, and so on. From 0.1.2 on, `major.minor.patch`
  matches the source release tag that ships it; see
  [Keep versions in sync](#keep-versions-in-sync).
- `sf` records each version as an alias in `packageAliases`, for example
  `checkr@0.1.0-1`. Commit those aliases; they are the record of what exists.
- The changelog heading for a beta uses the alias form: `## [0.1.0-1] - <date>`.
- Raise `minor` (or `major`) for a release with breaking changes, and `patch`
  for fixes, before cutting the version. Only one version per
  `major.minor.patch` can be promoted.
- Every version starts as a beta, which installs only in scratch orgs and
  sandboxes. Promoting it (see [Promote a version](#promote-a-version)) makes
  it installable in production.

### Code coverage

Version creation runs with `--code-coverage`. A beta can be created with any
coverage, but a version needs **75%** coverage of packaged Apex to be promoted.
CheckR holds itself to more: the real-org `apex-local-tests` scenario fails
below **85%** org-wide coverage or 75% coverage of `sfdx-source/checkr` Apex.
Check its latest run before cutting a version.

### Fields are hard to remove

Once a version containing a field, object, or global Apex signature is
installed anywhere, removing it from a later version only deprecates or
deletes it on upgrade, and subscriber metadata that references it blocks the
upgrade. Add schema deliberately, and remove unused schema before the first
version that ships it, as was done for the auto-create fields before 0.1.0.

## Keep versions in sync

One number names a release everywhere: the package version
(`major.minor.patch` of `versionNumber`), the source tag and `package.json`
version, the newest released changelog heading, and the `04t` that the README
and [installation](installation.md) point at. `npm run check:versions` checks
that they agree and runs in `npm test`. Between releases it allows
`versionNumber` to be one version ahead of `package.json`, and the promoted
package to be either of them.

Release in this order, one step at a time:

1. **Bump.** On a branch, set `versionNumber` to the next version
   (`0.1.3.NEXT`) and `versionName` to match (`ver 0.1.3`). Use the next patch
   for fixes; for a minor or major bump, release the source with `-b minor` or
   `-b major` in step 6. Merge the PR. `release:beta` refuses a `versionNumber`
   that is already promoted.
2. **Cut.** From updated `master`, `npm run release:beta` (see
   [Cut a beta](#cut-a-beta)).
3. **Test.** Run `install-smoke` and `install-upgrade` from the previous
   promoted `04t`, each in a fresh scratch org (see
   [Evidence](#evidence-before-sharing-a-version)).
4. **Promote** the beta (see [Promote a version](#promote-a-version)).
5. **Record.** `npm run release:record -- <04t>` marks the `version.json`
   released, points the README and installation at the new `04t`, and adds
   the version to `[Unreleased]` in the changelog. Commit it with the evidence
   on the `chore/package-<version>` branch and merge the PR.
6. **Publish.** From updated `master`:

   ```bash
   npm run release:publish -- --dry-run -m "feat: release <version>"
   npm run release:publish -- -m "feat: release <version>"
   ```

   This runs `check:versions -- --release`, which requires the promoted
   version to be the next patch of `package.json` and its `04t` to be in
   `[Unreleased]`, then `publish -b patch --push-public`, so the source tag
   and changelog heading match the package.

7. **Website.** The site's daily `update-product-versions` workflow reads the
   new GitHub release and its `version.json`; run it by hand to update at
   once.

Changes that touch only the docs or tooling do not need a release: merge them
to `master` and they ship with the next one. The docs site rebuilds on each
source release.

## Cut a beta

From a clean checkout of a commit on `origin/master`, with the Dev Hub
authenticated as `devHub` (or set `DEVHUB_ALIAS`):

```bash
npm run release:beta -- --dry-run   # git checks, then prints the sf commands
npm run release:beta                # node scripts/release/create-beta.mjs
```

The script:

1. refuses a dirty tree, and a `HEAD` that is not on `origin/master` unless
   `--allow-branch` is passed (for testing the script only, never a recorded
   release);
2. runs `sf package version create --package checkr --installation-key-bypass
--code-coverage --tag <commit> --wait 60`;
3. reads the result with `sf package version report --verbose` and writes
   `docs/evidence/releases/<version>/version.json`: the version, `04t`
   subscriber ID, `05i` package version ID, alias, commit, coverage, whether
   the coverage check passed, and the beta install URL
   (`https://test.salesforce.com/packaging/installPackage.apexp?p0=<04t>`)
   for sandboxes and scratch orgs;
4. commits that file and the new `packageAliases` entry on a new
   `chore/package-<version>` branch. It never pushes or promotes.
   `--no-branch` leaves both uncommitted.

`npm run test:release` tests the script with a stubbed `sf` and `git`; it is
part of `npm test`.

## Evidence before sharing a version

A version is not promoted or shared until its release branch has:

- `docs/evidence/releases/<version>/version.json` from the script;
- a passing `install-smoke` run of the version, in a fresh scratch org;
- when an earlier promoted version exists, a passing `install-upgrade` run
  from it;
- a `CHANGELOG.md` entry for the version, with its `04t` ID.

```bash
npm run org:evidence -- --scenario install-smoke --org <scratch> --package <04t>
npm run org:evidence -- --scenario install-upgrade --org <scratch> \
  --package <04t> --upgrade-from <previous 04t>
```

Each install scenario installs the package itself and must run alone, in its own
fresh scratch org. They refuse `checkr-evidence` and any non-scratch org.
Creating a scratch org (`--create-scratch`) needs the maintainer's explicit
confirmation. See [scenario details](evidence/scenarios.md#install-smoke).

Commit the evidence folders on the release branch and open a PR.

## Promote a version

Promotion releases a version for production installs. It cannot be undone,
and only one version per `major.minor.patch` can be promoted, so promote only
a version whose evidence is complete:

```bash
sf package version promote --package <04t> --target-dev-hub devHub --no-prompt --json
sf package version report --package <04t> --target-dev-hub devHub --json  # IsReleased: true
```

Then record it with `npm run release:record -- <04t>` (step 5 of
[Keep versions in sync](#keep-versions-in-sync)).
