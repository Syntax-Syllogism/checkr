# Changelog

All notable changes to CheckR are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.2] - 2026-11-26

### Added

- Starlight-based documentation site for CheckR

## [0.1.1] - 2026-11-26

### Added

- Add `CODE_OF_CONDUCT.md` and reword public docs

### Changed

- Gate CI on Salesforce Code Analyzer v5 (`npm run analyze`, CI job `code-analyzer`) and clear its findings across `sfdx-source/checkr` and `scripts`
- Change `CKR_ChecklistViewerController.updateChecklistItem` to take a `CKR_ChecklistItemUpdateRequest` request object. LWC callers send it under the `request` argument
- Pin AER v1.6.23 in CI (was v1.4.33). It counts `System.runAs` as a DML statement like a real org, which v1.4.33 did not

## [0.1.0-2] - 2026-10-20

Second beta of the unlocked `checkr` package. It contains no code changes since
0.1.0-1, only the documentation fixes below.

- Subscriber package version: `04tfj000000duX0AAI` (built from `a2b9252`, 94%
  code coverage).
- Install link (sandboxes and scratch orgs):
  <https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000duX0AAI>
- Upgrade evidence: [install-upgrade](docs/evidence/2026-10-20-install-upgrade-93563c6/README.md)
  from 0.1.0-1 in place.

- Document removing `CKR_BypassGate` and `CKR_Audit_Maintenance` from the
  System Administrator profile after every install and upgrade. Installing for
  Admins Only grants them, which lets every System Administrator bypass gates
  and maintain audit history.
- Document that unchecking a template's Active box hides it from New Checklist
  but does not stop its gates, and how to retire a template's gates by
  publishing a version with no rules.
- Replace the admin guide's unverified source-deploy install with the packaged
  install, after an API walkthrough of chapters 2 to 11 against beta 0.1.0-1.

## [0.1.0-1] - 2026-10-20

First beta of the unlocked `checkr` package (no namespace).

- Subscriber package version: `04tfj000000duWzAAI` (built from `182f413`, 94%
  code coverage).
- Install link (sandboxes and scratch orgs):
  <https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000duWzAAI>
- Install evidence: [install-smoke](docs/evidence/2026-10-20-install-smoke-0bf4aa2/README.md).

- Record beta install links on `test.salesforce.com` for sandboxes and scratch orgs.
- Include `sfdx-source/reference` in the local Apex gate using the unlimited
  developer license, with no skips. Audit-maintenance and gate-bypass tests
  assign permission sets to fresh Standard Users before switching context,
  and create audit fixtures as the admin. CI stays on checkr within its
  100-test cap.
- Extend smoke-user seed integration coverage for persona creation and repeated
  permission assignment, and viewer mutation coverage for ad hoc edits and
  reopening completed items.
- Add the `checkr` unlocked package and `npm run release:beta`
  (`scripts/release/create-beta.mjs`), which creates a beta version from
  `origin/master` and records it under `docs/evidence/releases/<version>/`.
- Add the `install-smoke` and `install-upgrade` org evidence scenarios, which
  install the package into a fresh scratch org and prove the gate and an
  in-place upgrade.
- Add `docs/installation.md` (install, permission sets, trigger shim and its
  test, upgrade, uninstall) and `docs/packaging.md`.
- Require Apex test coverage: `apex-local-tests` now fails below 85% org-wide or
  75% packaged Apex coverage. Round 1 real-org evidence passes 106 tests with
  95% org-wide and 95.3% packaged Apex coverage.

- Remove the unused auto-create schema before the first package version: `CKR_ChecklistTemplateVersion__c.CKR_AutoCreateEnabled__c`, `CKR_ChecklistTemplateVersion__c.CKR_AutoCreateLogic__c`, and `CKR_ChecklistInstance__c.CKR_CreatedFromAutoRule__c`, with their permission set entries and record page fields. `CKR_ChecklistInstanceCreateRequest` drops `createdFromAutoRule`, and `CKR_ChecklistCreateActionController.createChecklistAction` drops its `createdFromAutoRule` parameter. Source deploys do not delete fields, so orgs where CheckR was already source-deployed keep the three fields until they are removed with a destructive manifest. No data migration is needed; nothing read the fields.

- Add `LICENSE` (MIT), `CONTRIBUTING.md`, and a `docs/README.md` index; rewrite the README to match the code. List every system-mode site in `docs/architecture.md`, enforced by `npm run test:system-mode`. Org evidence records repo-relative paths, and `npm test` now runs the public-tree release check.

- Align the toolchain with Warden: Node 22, API 67.0, and AER v1.4.33 pinned in CI. `npm test` now runs the full no-org suite (SLDS, prettier, afmt, LWC Jest, markdownlint, and the metadata/doc tests), `scripts/gate.mjs` runs it with AER, and commitlint and lint-staged run on commit. The formatting baseline is listed in `.git-blame-ignore-revs`.

- Add a chaptered admin guide with screenshots (`docs/admin-guide/`), a gate-blocking-saves runbook (`docs/runbooks/`), a screenshot capture script (`npm run docs:screenshots`), and a docs-image test in `npm test`. The reporting guide moved to `docs/admin-guide/10-reports.md`.

- Add object-model, security, and platform-constraints reference docs, a `SECURITY.md` policy, a generated permission set access table, and an object-model metadata test in `npm test`.

- Add operational report types, three starter reports, a viewer-context dashboard, creation-age bands, reporting metadata checks and an admin reporting guide.

- Protect audit and bypass history against updates, deletes and instance cascades; add temporary Audit Maintenance privileges, retention guidance and an audit-integrity evidence scenario.

- Add audited gate bypass via a dedicated custom permission or org/profile/user hierarchy setting, with bulk audit writes and an explicit org-evidence scenario.

- Add Publish Version for Draft checklist template versions, with atomic status
  cutover, publisher audit fields, and current-version pointer updates.
- Protect Published and Historical versions, template items, and gate rules from
  edits and prevent direct publication outside the service.
- Evaluate checklist gates using an existing instance's version, with the
  Published version as fallback for records without an instance.
- Pin ungated inserts and add the `version-cutover` org evidence scenario.
