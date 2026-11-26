---
title: "Scenario details"
---

Run from the project root with an authenticated administrator org alias.
Salesforce CLI, AER, and dependencies must be installed. Harness unit tests use
stubs and need no org, credentials or AER execution.

## apex-local-tests

Runs AER on the same local source with `CKR_Admin` and real-org RunLocalTests
with code coverage and a 30-minute wait. Saves test results, pass/fail counts,
class/overall coverage and method-by-method AER comparison. Missing methods and
different outcomes are recorded in `aer-comparison.json` and summary metrics.
Differences are observations; an empty/failing suite, overall org coverage
below 85%, or Checkr package Apex coverage below 75% fails the scenario.
Package coverage counts only classes and triggers under `sfdx-source/checkr`,
the code that `sf package version create --code-coverage` measures. Unrelated
org tests appear as extra methods.
AER license or execution errors are failures, not equivalence evidence.

## gate-block-pass

Requires an existing scratch org (or explicit `--create-scratch` after user
confirmation), an available Salesforce user license (the `Salesforce` license, not Platform) and the Standard User profile.
Salesforce CLI scratch-user provisioning authenticates a fresh worker without
human login; it cannot provision that session in a sandbox or production org.

Creates a Standard User with `CKR_User`, an Account owned by that user, and a
Published Account template with one required checkbox and an active Rating to
Hot gate. Saves via the worker's data API session, which does not need Author
Apex. Requires the exact configured gate error. Creates an instance through the
application service and completes its item through the viewer controller as
the admin fixture actor. Retries as the worker and verifies persisted Hot
rating. Non-admin checklist completion is outside this scenario's assertion.

## insert-gating

Creates an active Published-version gate through the publish service and inserts
an Account whose Hot rating matches the rule, without an instance. Inserts are not gated:
success with no errors is required. A blocked insert, including
a gate error, fails the scenario. Evidence records the result and exact errors.
The gateway and reference trigger behavior are unchanged.

## version-cutover

Creates two Accounts and a Draft v1 template with a required item and a Rating
to Hot rule, then publishes through the service. Creates and completes an
instance on Account A through the application service and viewer controller.
Publishes v2 with a stricter rule (any Rating change). Verifies that updating A
succeeds, updating Account B without an instance is blocked by the exact v2 gate
error, v1 is Historical and exactly one version is Published. Also verifies that
an API edit to the Published v2 rule fails. Fixture cleanup removes the entire
scoped template graph through master-detail cascade after removing instances.

## bulk-200

Seeds 200 Accounts and three active rules on separate Published versions.
Indexes 0-99 have complete instance snapshots for all three versions; indexes
100-199 have none. These system-mode fixtures do not prove the item completion
API in bulk. Changes all 200 ratings from Cold to Hot in one
`Database.update(changes, false)`.

Records every ID, input index, expected allowance, actual success and exact
errors. Requires exactly 100 allowed and 100 gate-blocked records, all matching
their expected indexes. Measures SOQL and CPU immediately around the DML,
excluding setup, input queries and result formatting. SOQL must be **<= 6**,
including partial-save trigger retries. CPU is recorded without a threshold.

## Isolation and deferred coverage

Each scenario creates a unique CKREvidence key and deletes only its matching
Accounts, templates, versions, rules, instances, items and audit rows. It never
invokes the smoke seeder's org-wide reset. Worker cleanup uses separate
setup-object transactions. With `--keep`, fixtures and worker access remain;
evidence records IDs while redacting usernames. Conflicting existing org
configuration is reported as failure rather than disabled.

Install/upgrade belong to ckr-beta-package-release. Bypass awaits a defined
capability. Those catalog entries are placeholders, not runnable contracts.

## bypass

Creates two isolated Standard Platform User identities. They use the Salesforce
Platform license so they fit a scratch org with only two Salesforce licenses.
One has `CKR_GateBypass`, the other starts with no bypass and must receive the
exact gate error. Both own an Account with no checklist. The scenario enables user hierarchy rows and proves
that blocked updates save, the permission source wins when both switches are
on, and otherwise the setting source is used. An allowed transition must not
add another event. Audits must identify actor, record, object, rule, source,
time and details. Cleanup removes only these users' setting rows and these
fixture Accounts' bypass events before deleting fixture templates and Accounts.

```sh
npm run org:evidence -- --scenario bypass --org checkr-evidence
```

`CKR_GateBypassIT` lives with the reference Account trigger and verifies a
`System.runAs` save using a real permission-set assignment. Run it in the org;
AER does not resolve the dynamic custom-permission assignment.

## audit-integrity

Uses one Standard Platform User with CKR_Admin. System-authored audit inserts
succeed; API audit/bypass updates and deletes fail, and audited instance deletion
fails with the guard message. A temporary CKR_AuditMaintenance assignment permits
audit and bypass updates/deletes, then is removed. Fixtures are cleaned with a
scoped temporary maintenance grant to the caller. No org is created or reset.
The scenario also runs `CKR_AuditRecordGuardTest` and
`CKR_AuditMaintenanceIT`, which verifies assigned permission via `System.runAs`,
including authorized instance cascade, in a real org (AER cannot resolve dynamic
custom permission assignments). The guard tests also verify that deleting an
audited item fails and preserves the audit's item lookup, while an unaudited item
remains deletable. The maintenance test verifies that an assigned maintainer can
delete an audited item and that Salesforce clears its SetNull lookup while
retaining the audit event.

## install-smoke

Requires `--package <04t>` and a fresh scratch org; it refuses `checkr-evidence`,
`CKR_EVIDENCE_ORG` and any non-scratch org. It installs the package version with
`sf package install` (polling the install request for up to 30 minutes) and
deploys nothing from `sfdx-source/checkr`. Checks that `package installed list`
reports the version, that the five permission sets, the three LWCs and the
`CKR_SupportedObject__mdt` Account record exist, then deploys only the reference
Account trigger shim as a subscriber would. It then runs the `gate-block-pass`
setup and run: a `CKR_User` is blocked, completes the checklist, and saves.

## install-upgrade

Requires `--package <04t>` and, for a real upgrade, `--upgrade-from <04t>`, with
the same org rules as `install-smoke`. Installs the older version, deploys the
reference shim, and runs `gate-block-pass` to leave a template, published
version, completed instance, completed item and audit events. It then upgrades
in place to `--package`, checks that `package installed list` reports the new
version, and compares those rows before and after. After the upgrade the
completed checklist still lets the worker save, and a new Account without an
instance is still blocked by the published version. Without `--upgrade-from` it
records the upgrade as skipped and proves only the gate on `--package`.
