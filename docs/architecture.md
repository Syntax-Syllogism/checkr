---
title: "Apex architecture"
---

## Layers and data-access seams

Triggers and `@AuraEnabled` controllers are thin. Logic lives in services; queries live in selectors; DML lives in gateways. Each of these is reached through an interface (a _port_) and resolved by `CKR_AppFactory`:

```apex
CKR_IChecklistGateService gate = (CKR_IChecklistGateService) CKR_AppFactory.getInstance(
  CKR_IChecklistGateService.class
);
```

`CKR_AppFactory` is a type-keyed registry. `getInstance` returns the test override when one is registered, otherwise the default implementation. `setMock(Type, Object)` and `clearMocks()` are `@TestVisible` and are the only test hooks.

Base classes:

- `CKR_ServiceBase` (services): helpers to resolve the selectors, gateways and services a service uses.
- `CKR_SelectorBase` (selectors): `queryWithBinds`, `countWithBinds` (both user mode) and `querySystemModeWithBinds` (system mode, see below).

Both DML gateways take `CKR_DmlMode` for insert, update, and delete.
`ALL_OR_NONE` rolls back the batch when any row fails. `PARTIAL` returns each
row's result and preserves successful writes. A null mode uses
`ALL_OR_NONE`. The normal gateway uses `AccessLevel.USER_MODE`, as do the
normal selector query helpers.

`CKR_ParentAccess` exposes read and edit flags derived from the strongest
`CKR_ParentAccessLevel` returned by the parent access gateway. The viewer
accepts `CKR_ChecklistItemUpdateRequest` and `CKR_AdHocItemRequest`. The
create action reuses `CKR_ChecklistInstanceCreateRequest`. LWC callers send
those DTOs under the `request` argument.

The instance-item and template-version triggers pass `Trigger.operationType`
to `CKR_ChecklistInstanceItemTriggerHandler` and
`CKR_TemplateVersionTriggerHandler`. The handlers route save and delete
operations to lifecycle checks and audit retention guards.

### User-mode updates

A user-mode update fails if the record carries any field the user cannot write, including the master-detail parent (which cannot be granted in a permission set). Controllers therefore send a fresh SObject holding the Id and only the fields the flow changes, never the whole queried record.

## System-mode exceptions

Everything else runs in user mode. The exceptions fall into five categories, all deliberate. The [system-mode sites](#system-mode-sites) table lists every class that runs in system mode, and `npm run test:system-mode` fails when the table and the code diverge.

1. **Gate evaluation** (`CKR_ChecklistGateSelector`, `CKR_DefaultSupportedObjectSelector`, `CKR_DefaultChecklistGateService`, `CKR_ChecklistTriggerGateway`). All are `inherited sharing`. The gate is a control on the _parent_ object's save, so it must fire for every user, including one who has no CheckR permission set. If the gate read in user mode, a user without access to gate rules would silently bypass the gate. The supported-object read is system mode because it is non-sensitive configuration metadata.
2. **Audit writes** go through `CKR_ISystemDmlGateway` (`CKR_SystemModeDmlGateway`). Users have no create permission on `CKR_ChecklistAuditEvent__c`, so they cannot forge audit events; the application writes them on the user's behalf. Gate bypass audits on `CKR_GateBypassEvent__c` also use this gateway from `CKR_DefaultChecklistGateService`, with all-or-none insertion. `CKR_Admin` can read all bypass events; the dedicated bypass permission set grants read-only object access.

3. **Derived `CKR_IsComplete__c` writes** (`CKR_ChecklistViewerController.updateChecklistInstanceRollup` and `CKR_DefaultChecklistInstanceService.insertSnapshot`) go through `CKR_ISystemDmlGateway`. `CKR_IsComplete__c` feeds the gate (exception 1), so `CKR_User` has read-only FLS on it and the application derives it on the user's behalf.

4. **Gate-driving item fields** (`CKR_Required__c`, `CKR_Completed__c`, `CKR_CompletedBy__c`, `CKR_CompletedOn__c`) are read-only for `CKR_User`. The application writes them in system mode through `CKR_ISystemDmlGateway`: template item inserts in `CKR_DefaultChecklistInstanceService.insertSnapshot` and completion state on `updateChecklistItem`. Universally required fields (for example `CKR_SourceType__c`) cannot carry field permissions in Salesforce; they are always accessible to users with object access.

5. **Audit retention reads** (`CKR_AuditRetentionSelector`, `without sharing`): a system-mode aggregate query detects all audit children before instance or item deletion, regardless of the actor's visibility. This prevents master-detail cascade from silently erasing hidden history and item deletion from clearing audit lookups. `CKR_AuditRecordGuard` exempts only `CKR_Audit_Maintenance` for instance/item deletion. The same selector checks bypass-referenced rules before template/version cascades; those parents stay protected for maintainers too, matching the bypass rule lookup Restrict constraint. Export and explicitly remove linked bypass events before deleting configuration; see [retention](records-and-retention.md).

### System-mode sites

Each row is a class under `sfdx-source/checkr/main/classes` that uses a system-mode marker: `SYSTEM_MODE`, `querySystemModeWithBinds`, `systemDmlGateway()`, `CKR_ISystemDmlGateway`, or `without sharing`. Categories refer to the numbered list above; _seam_ rows are the shared plumbing the sites use.

| Class                                 | Methods                                                                                                                     | Why system mode                                                                        | Covering test                             |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------- |
| `CKR_ChecklistGateSelector`           | `selectActivePublishedGateRulesByObjectApiName`, `selectInstancesByRecordId`                                                | 1. The gate must read rules and instances for every user.                              | `CKR_ChecklistGateSelectorTest`           |
| `CKR_DefaultSupportedObjectSelector`  | `selectActiveByObjectApiName`                                                                                               | 1. Non-sensitive configuration metadata that drives the gate.                          | `CKR_ChecklistSupportServicesTest`        |
| `CKR_DefaultChecklistGateService`     | `applyBypass`                                                                                                               | 2. Users cannot create `CKR_GateBypassEvent__c`; the bypass audit is written for them. | `CKR_DefaultChecklistGateServiceTest`     |
| `CKR_DefaultChecklistAuditService`    | `record`                                                                                                                    | 2. Users cannot create `CKR_ChecklistAuditEvent__c`, so they cannot forge audits.      | `CKR_ChecklistSupportServicesTest`        |
| `CKR_ChecklistViewerController`       | `updateChecklistItem`, `updateChecklistInstanceRollup`                                                                      | 3 and 4. Completion state and `CKR_IsComplete__c` feed the gate.                       | `CKR_ChecklistViewerControllerTest`       |
| `CKR_DefaultChecklistInstanceService` | `insertSnapshot`                                                                                                            | 3 and 4. Template item inserts carry `CKR_Required__c`; `CKR_IsComplete__c`.           | `CKR_DefaultChecklistInstanceServiceTest` |
| `CKR_AuditRetentionSelector`          | `selectBypassReferencedTemplateIds`, `selectBypassReferencedVersionIds`, `selectAuditedItemIds`, `selectAuditedInstanceIds` | 5. `without sharing`: deletion guards must see audit children the actor cannot.        | `CKR_AuditRecordGuardTest`                |
| `CKR_SelectorBase`                    | `querySystemModeWithBinds`                                                                                                  | Seam: the only system-mode query helper, used by the selectors above.                  | The selector tests above                  |
| `CKR_ServiceBase`                     | `systemDmlGateway`                                                                                                          | Seam: resolves `CKR_ISystemDmlGateway` for services.                                   | The service tests above                   |
| `CKR_ISystemDmlGateway`               | `doInsert`, `doUpdate`, `doDelete`                                                                                          | Seam: the system-mode DML port, separate from `CKR_IDmlGateway`.                       | `CKR_AppFactoryTest`                      |
| `CKR_SystemModeDmlGateway`            | `doInsert`, `doUpdate`, `doDelete`                                                                                          | Seam: the only `AccessLevel.SYSTEM_MODE` DML.                                          | `CKR_DefaultDmlGatewayTest`               |
| `CKR_AppFactory`                      | `getInstance`                                                                                                               | Seam: binds `CKR_ISystemDmlGateway` to `CKR_SystemModeDmlGateway`.                     | `CKR_AppFactoryTest`                      |

`CKR_ChecklistTriggerGateway` is part of gate evaluation (category 1) but has no row: it is `inherited sharing` and reaches system mode only through `CKR_DefaultChecklistGateService` and the gate selectors.

Operational reports and the CheckR Operations dashboard add no Apex and no system-mode path. They are declarative metadata that runs under the viewer's sharing and field access; see the [admin guide](admin-guide/10-reports.md#operational-reporting).

Do not add other system-mode paths without documenting them here.

## Permission sets

- `CKR_Admin`: administration of templates and gate rules, with view-all read-only audit access. Also grants the `CKR_TemplateVersionPublishController` class, which backs the Publish Version action.
- `CKR_User`: runtime access. Create/update checklist instances and items, delete ad hoc items, read templates and gate rules. No View All Records (sharing applies), no edit on derived rollup fields, no template or gate administration and no audit create. Grants access to the two `@AuraEnabled` controllers.
- `CKR_ReadOnly`: read only on objects and fields. It grants no Apex class access, so it cannot call the `@AuraEnabled` controllers.
- `CKR_GateBypass`: the `CKR_BypassGate` custom permission plus read-only access on `CKR_GateBypassEvent__c`. Operational only, not part of routine assignments; see [gate bypass operations](gate-bypass.md) and [security operations](security.md).
- `CKR_AuditMaintenance`: temporary audit edit/delete and view/modify-all plus the maintenance custom permission. Assign separately; never routine access.

`CKR_Admin`, `CKR_User`, and `CKR_ReadOnly` all grant read (never edit) on the `CKR_AgeBand__c` report formula, so the viewer-run operational reports keep their age grouping for every runtime user.

Required fields and master-detail fields cannot appear in permission sets, so they are absent from every set above.

## Testing

### Stub API mocks

Unit tests do not hand-write fake classes. `CKR_Mocks.MethodRecorder` implements `System.StubProvider`, records every call, and returns canned responses:

```apex
CKR_Mocks.MethodRecorder dml = new CKR_Mocks.MethodRecorder()
  .when('doUpdate', new List<Database.SaveResult>());
CKR_AppFactory.setMock(CKR_IDmlGateway.class, CKR_Mocks.stub(CKR_IDmlGateway.class, dml));
// ... run code under test ...
Assert.areEqual(1, dml.callCount('doUpdate'));
List<SObject> sent = (List<SObject>) dml.argumentsAt('doUpdate', 0)[0];
```

Recorder methods: `when`, `whenSequence` (ordered responses, last repeats), `whenThrow`, `whenThrowOnCall` (fails one numbered call, for rollback tests), `assignsIds` (gives Id-less records a fake Id, as a real insert would), `performsRealUpdates` (explicit integration tests only), `callCount`, `lastArguments`, `argumentsAt`.

`Database.SaveResult` has no public constructor. Build one by JSON-deserializing `{"success":true,"id":"..."}`. A stub that returns the wrong type for a method fails at the call site with a type error, so give every stubbed method a response of the right type.

### Test records

`CKR_TestRecords.build(SObjectType, Map<String, Object>)` builds an in-memory record by JSON-deserializing the field map (no DML, so no required-field or validation failures). It throws `CKR_TestRecordsException` on an unknown field name, because deserialization would otherwise ignore typos silently. `fakeId(type, n)` returns a valid deterministic Id.

### Test tiers

| Tier              | How                                                                                                                                                | Covers                                                                                                                                                                                         |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Node (no org)     | `npm test` (lint, SLDS, prettier, afmt, LWC Jest, markdownlint, and the `test:*` suites; full list in [testing](testing.md#no-org-suite-npm-test)) | Static checks and LWC unit tests, plus report and report-type XML, evidence-harness units, object-model and security docs against metadata, the system-mode inventory, and admin-guide images. |
| Analyzer (no org) | `npm run analyze` (the gate runs it with `--if-installed`; CI job `code-analyzer`)                                                                 | Salesforce Code Analyzer v5 over `sfdx-source/checkr` and `scripts`: zero findings at every severity and no engine errors.                                                                     |
| AER (no org)      | `npm run test:apex` (checkr + reference, with no skips), run by `node scripts/gate.mjs`; CI runs checkr only                                       | Unit tests and DB-backed `*IT` / selector tests, in the AER in-memory database.                                                                                                                |
| Real org          | `npm run org:evidence` ([evidence](evidence/README.md)); ad hoc `sf`/`sfq` apex run                                                                | Real sharing, `UserRecordAccess`, permission-set enforcement, Playwright e2e.                                                                                                                  |

Commands, the CI job, hooks, and toolchain pins are in [testing](testing.md).

Notes on AER:

- `-p CKR_Admin` assigns the permission set to the test user. Without it, user-mode queries fail with "No such column" because FLS hides every field.
- AER treats master-detail fields as FLS-gated, unlike Salesforce.
- The free tier allows 100 test methods. Local runs use an unlimited developer license; CI runs checkr only, capped at 100 tests by `scripts/aer-capped.mjs`. Never commit `AER_LICENSE_KEY`.
- Behaviour AER cannot confirm (`UserRecordAccess` in user mode, `countQueryWithBinds(AccessLevel)` at API 66, sharing rules) needs a real-org run; see [org evidence](evidence/README.md).

## Template version lifecycle and gate evaluation

`CKR_IChecklistTemplateVersionService.publish(Id)` resolves to
`CKR_DefaultTemplateVersionService`. The implementation locks the template row
through `CKR_IChecklistTemplateVersionSelector`, then rereads the requested
version after the lock. Only Draft versions with at least one item can publish.
It retires all previous Published versions to Historical, publishes the Draft
with `CKR_PublishedBy__c` and `CKR_PublishedOn__c`, and updates
`CKR_CurrentPublishedVersion__c`. User-mode DML runs under a savepoint: any
failure rolls back the entire cutover even when a caller catches the exception.
The shared template lock serializes concurrent publishers.

The version trigger delegates to `CKR_TemplateVersionLifecycleService`, which
rejects direct lifecycle transitions and edits to Published/Historical versions.
Only version IDs held privately by the publish service during its DML may change
lifecycle status. Cross-object validation rules reject inserts and edits of items
and gate rules whose parent version is Published or Historical. Thin delete
triggers also prevent direct deletion of immutable versions, items, and rules.
Whole-template deletion still uses Salesforce master-detail cascade (for example,
scoped evidence-fixture cleanup). No new
system-mode exception is introduced. The admin action calls the service through
`CKR_TemplateVersionPublishController`; see [publishing instructions](template-version-publishing.md).

The gate selector reads active rules from both Published and Historical
versions and loads all matching instances, including incomplete instances, in
system mode. For each parent record and template, an existing instance selects
only its own version's rules. A matching rule blocks only if that instance is
incomplete. Without an instance, only the Published version's rules apply and a
matching rule blocks. Rules keep their sort order (`CKR_SortOrder__c`, then
`CreatedDate`), and the first blocking rule supplies the error. Historical rules
for other instance versions do not apply. Publishing never migrates instances.

**Inserts are not gated.** In `before insert`, Salesforce has
no record Id and `Trigger.newMap` is null. `CKR_ChecklistTriggerGateway` returns
without calling the gate service. Checklist attachment requires a persisted
record. A unit test pins this early return; `CKR_InsertGatingIT` exercises the
reference Account trigger, and the `insert-gating` evidence scenario asserts
that matching inserts succeed.

## Audited gate bypass

`CKR_IGateBypass` resolves through `CKR_AppFactory` to `CKR_GateBypass`.
The service caches the effective source per running user per transaction:
`CKR_BypassGate` custom permission first, then the effective hierarchy
`CKR_Settings__c.CKR_BypassGate__c`, otherwise null. Explicit false values at a
more specific scope override true values inherited from org or profile.

Gate evaluation completes normally before applying bypass. Only blocked results
are changed to allowed; their existing `gateRuleId` identifies the first blocking
rule. One bulk system-mode insert records actor, parent Id and object, rule,
source, time and original error. Allowed saves emit nothing. Evaluation errors
and audit insertion failures propagate, preventing unaudited saves. Events share
the parent save transaction and roll back if the save fails. Inserts remain
ungated. The audit object is private and independent of checklist instances;
deleting a gate rule clears its lookup without deleting the audit.

AER supports hierarchy resolution and transaction caching, but dynamic
`PermissionSetAssignment` to the already running user does not refresh
`FeatureManagement.checkPermission` in AER. Integration tests assign permissions
to a fresh Standard User before entering `runAs` for that user. Permission assignment, source precedence and
real trigger updates are confirmed by the successful
[`bypass` org scenario](evidence/2026-10-20-bypass-ef9f45b/README.md) and
[reference `CKR_GateBypassIT` test](evidence/2026-10-20-gate-bypass-it-639d604/README.md).
Earlier initialization failures remain in the evidence history. See the
[org evidence catalog](evidence/README.md) and [operator instructions](gate-bypass.md).
