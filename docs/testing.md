---
title: "Testing, gate, and CI"
---

How CheckR is verified without an org, how the gate and CI run the same checks,
and which tool versions they depend on. The test tiers and what each covers are
in [architecture: test tiers](architecture.md#test-tiers). Real-org checks are
in [org evidence](evidence/README.md).

## No-org suite: `npm test`

`npm test` runs these in order and stops at the first failure:

1. `npm run lint`: ESLint on Aura and LWC JavaScript, then `slds-linter` on LWC
   HTML and CSS.
2. `npm run prettier:verify`: Prettier on Markdown, JSON, YAML, XML, and the LWC
   and page formats. Apex is skipped.
3. `npm run format:apex:verify`: afmt check for Apex, configured by `.afmt.toml`.
4. `npm run test:unit` and `npm run test:unit:inband`: LWC Jest, in parallel and
   in band.
5. `npm run lint:md`: markdownlint-cli2 over all Markdown.
6. `npm run test:org-harness`, `test:reporting`, `test:object-model`,
   `test:docs-images`, `test:system-mode`, `test:permission-sets`, and
   `test:release`: Node tests for the evidence harness,
   reporting metadata, the object-model doc, the admin-guide images, the
   system-mode sites table in `docs/architecture.md`, permission set class
   access, the public-tree
   release check, and the beta-release script (`create-beta.mjs`) against a
   stubbed `sf` and `git`.
7. `npm run test:analyzer` checks analyzer command construction, optional
   plugin discovery, exit status, and engine errors using a stubbed `sf`.

`scripts/gate.mjs` also warns, without failing, when
`sfdx-source/checkr/main/default` exists. That folder is ignored retrieve
output; delete it so it is not deployed with the package.

Notes:

- afmt owns Apex (`*.cls`, `*.trigger`, `*.apex`, `*.apexc`). `.prettierignore`
  skips those files, and it also keeps `docs/evidence/**`
  verbatim.
- afmt 1.0.0 must be on `PATH`. CI installs it from the upstream release tarball.
- `npm test` needs no org, no DevHub secrets, and no AER. Apex runs in a
  separate step.

## Static analysis with `npm run analyze`

Salesforce Code Analyzer v5 scans `sfdx-source/checkr` and `scripts`. Its
threshold includes every severity. The runner also checks the engine log and
writes `code-analyzer-results.json` for inspection. The reference package
contains separately maintained admin smoke seeds and integration tests, so it
stays outside the analyzer scope.

`code-analyzer.yml` and the files it references explain each override. The
ESLint config applies Node globals and runtime exceptions only to Node scripts.
CPD's JavaScript extensions omit `.mjs` because its lexer fails on script
shebangs. The custom PMD rule `CheckrMethodNamingConventions` permits
`subject_behaviour` test names and keeps camelCase for production methods.

Tests that assert CRUD, FLS, or sharing behavior use `System.runAs` with an
inserted test user. Database wiring tests that depend on the administrative
context may use the existing running user. Pure logic and stubbed unit-test
classes document their class-level exception to the PMD `runAs` rule.

## Gate: `scripts/gate.mjs`

`node scripts/gate.mjs` runs the local verification gate.

1. Runs `npm ci --no-audit --no-fund` only when `node_modules` is absent, as in
   a fresh worktree.
2. Runs `npm test`.
3. Runs `npm run analyze -- --if-installed`. This skips when the Salesforce
   CLI or an installed analyzer plugin is absent. A JIT-only listing means the
   plugin still needs installation.
4. Checks that `aer` is on `PATH`.
5. Warns if the local `aer` version differs from the version pinned in
   `scripts/gate.mjs`.
6. Runs `npm run test:apex` against both `sfdx-source/checkr` and
   `sfdx-source/reference` with `-p CKR_Admin`, with no skips.

The gate never calls an org. Using AER requires a license: without one it stops
at 100 test methods, and the suite has more. Set `AER_LICENSE_KEY` (never
commit it). AER does not run in CI, because the license does not cover it, so
run the gate before you open a pull request.

## CI: `.github/workflows/ci.yml`

The `lint-and-test` job runs on `ubuntu-latest` with Node 22 and the npm cache.

1. Check out the repository.
2. `npm ci`.
3. Download afmt 1.0.0 and add it to `GITHUB_PATH`.
4. `npm test`.

CI does not run the Apex tests; they run only in the local gate.

The `code-analyzer` job uses Node 22, Temurin Java 17, Salesforce CLI
`2.158.7`, and Code Analyzer `5.13.0`. It runs `npm run analyze` after
installing dependencies. Each pull request must pass both checks.

The former scratch-org `integration.yml` was removed in `fd6de64`. Real-org
checks run only through `npm run org:evidence`, so CI does not print
human-readable `sf` test output and does not need DevHub secrets.

## Other scripts (outside the gate and CI)

- `npm run test:lwc` is the same `sfdx-lwc-jest` runner as `test:unit`.
  `test:lwc:coverage` and `test:unit:coverage` add coverage; `test:unit:watch`
  and `test:unit:debug` are for local work.
- `npm run test:e2e` runs the Playwright suite in `tests/playwright` against a
  live org, so it is not in `npm test`, the gate, or CI. It reads `SF_BASE_URL`
  and the auth file from `.env.playwright` (template:
  `.env.playwright.example`). `npm run test:e2e:setup` fills that file from the
  org alias (`SF_ORG_ALIAS`, default `checkr`), and `npm run test:e2e:auth`
  saves the browser sign-in to `SF_AUTH_FILE` (default
  `.playwright/auth/salesforce.json`). Both paths are git-ignored.
  `test:e2e:headed` and `test:e2e:ui` run the same suite visibly.

## Commit and staging hooks

- `.husky/pre-commit` runs `lint-staged`:
  - Prettier writes staged web, data, and XML files. For Markdown it runs
    Prettier, then `markdownlint-cli2 --fix`.
  - afmt writes staged Apex.
  - ESLint runs on staged Aura and LWC JavaScript.
  - Related LWC Jest tests run for staged LWC files.
- `.husky/commit-msg` runs commitlint with `@commitlint/config-conventional`, so
  a message such as `bad message` is rejected.
- The formatting baseline is commit `c728cef`, listed in
  `.git-blame-ignore-revs`. Pass `--ignore-revs-file .git-blame-ignore-revs` to
  `git blame` to skip it.

## Toolchain

| Item           | Value                                                         | Where                              |
| -------------- | ------------------------------------------------------------- | ---------------------------------- |
| Node           | 22 or later (`engines.node` is `>=22`)                        | `package.json`, `ci.yml`           |
| afmt           | 1.0.0 on `PATH`                                               | `ci.yml`, [README](../README.md)   |
| AER            | v1.6.23; the local binary must match                          | `scripts/gate.mjs`, `aer upgrade`  |
| Salesforce API | 67.0 for `sourceApiVersion` and every metadata `<apiVersion>` | `sfdx-project.json`, `sfdx-source` |

## AER pin and known tool issues

- The local Apex gate includes every test in the reference package, including
  `CKR_SmokeSeedIT`, `CKR_AuditMaintenanceIT`, and `CKR_GateBypassIT`.
  Permission tests assign permission sets to a fresh Standard User inside
  `runAs` of the current admin, then exercise behavior in `runAs` of that user.
  Assigning permission sets to the already running user is not reflected by
  AER. Audit fixtures are created as the admin before switching users.

- The gate pins AER v1.6.23, the latest stable release. Keep the local binary on the
  same version with `aer upgrade`, or install it with
  `brew install octoberswimmer/tap/aer`.
- On 2026-11-25 at API 67.0, v1.6.23 passed all 113 Apex tests, including the
  4 user-mode tests that failed on v1.5.4. It also counts each `System.runAs`
  as one DML statement, as a real org does; v1.4.33 does not. A test that
  asserted zero DML statements inside `runAs` passed on v1.4.33 and failed in
  the org, so assert DML as a delta measured inside the `runAs` block.
- On 2026-10-20 at API 67.0, v1.4.32, v1.4.33, and v1.5.10 passed all 100 Apex
  tests. v1.5.4 failed 4 user-mode tests with "fields being inaccessible":
  - `CKR_AuditRecordGuardTest`: `triggersAndSystemInsert` and
    `referencedGateRuleDeletion`.
  - `CKR_DefaultTemplateVersionServiceTest`:
    `directStatusAndPublishedEditsRejected` and
    `reparentingImmutableChildrenRejected`.

  The same tests pass on v1.5.4 at API 66.0.

- Earlier pins avoided v1.5.5+ and v1.4.17+ for a `CKR_UserModeIT` ad-hoc delete
  failure that no longer reproduces. No upstream issue was opened, because the
  newer releases pass.
- File AER issues at <https://github.com/octoberswimmer/aer-dist/issues>.
- AER does not enforce record sharing. `*IT` tests that depend on sharing, such
  as `CKR_UserModeIT` parent Account access, must also pass in a Private-OWD org
  through `npm run org:evidence`.
