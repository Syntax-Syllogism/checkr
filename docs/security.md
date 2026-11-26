# Security

This page answers the questions a Salesforce security reviewer asks about
CheckR: who gets which access, how records are shared, where Apex runs in
system mode and why, how gate bypass is controlled, and how audit history is
protected. Field-level detail is in the [object model](object-model.md); the
Apex rationale is in [architecture](architecture.md).

## Permission sets

| Permission set         | For                                                                                                       | Custom permission       |
| ---------------------- | --------------------------------------------------------------------------------------------------------- | ----------------------- |
| `CKR_Admin`            | Business admins who configure templates, items, gate rules, and publish versions.                         | none                    |
| `CKR_User`             | End users who attach checklists and work items on records they can see.                                   | none                    |
| `CKR_ReadOnly`         | Reviewers and reporting users. No bypass history and no Apex class access, so no viewer or create action. | none                    |
| `CKR_GateBypass`       | Trusted integration identities and operators during migrations or incident fixes.                         | `CKR_BypassGate`        |
| `CKR_AuditMaintenance` | Trusted operators doing approved, exported audit maintenance. Temporary.                                  | `CKR_Audit_Maintenance` |

`CKR_GateBypass` and `CKR_AuditMaintenance` are operational. Assign them
separately and remove them promptly; never include them in routine admin or
end-user assignments.

### Object access

The table below is generated from the permission set XML by
`node scripts/permissionSetCrud.mjs --write`. The object-model test fails if it
drifts from metadata. C, R, E, D are create, read, edit, delete; VA is View All
Records; MA is Modify All Records; `-` is no access.

<!-- crud-table:start -->

| Object                            | `CKR_Admin` | `CKR_User` | `CKR_ReadOnly` | `CKR_GateBypass` | `CKR_AuditMaintenance` |
| --------------------------------- | ----------- | ---------- | -------------- | ---------------- | ---------------------- |
| `CKR_ChecklistAuditEvent__c`      | R VA        | R          | R VA           | -                | RED VA MA              |
| `CKR_ChecklistGateRule__c`        | CRED VA MA  | R          | R VA           | -                | -                      |
| `CKR_ChecklistInstanceItem__c`    | CRED VA MA  | CRED       | R VA           | -                | -                      |
| `CKR_ChecklistInstance__c`        | CRED VA MA  | CRE        | R VA           | -                | R                      |
| `CKR_ChecklistTemplateItem__c`    | CRED VA MA  | R          | R VA           | -                | -                      |
| `CKR_ChecklistTemplateVersion__c` | CRED VA MA  | R          | R VA           | -                | -                      |
| `CKR_ChecklistTemplate__c`        | CRED VA MA  | R          | R VA           | -                | -                      |
| `CKR_GateBypassEvent__c`          | R VA        | -          | -              | R                | RED VA MA              |

<!-- crud-table:end -->

Points worth noting:

- No permission set grants create on either audit object. The application
  writes audit and bypass events in system mode, so users cannot forge them.
- `CKR_User` has no View All, so sharing decides which instances a user sees.
  It cannot delete instances. It has item delete so the viewer can remove ad
  hoc items; the viewer refuses to remove template-derived items, but the
  object permission itself does not distinguish them, so an API delete of a
  template-derived item without audit history is not blocked.
- `CKR_User` has read-only field access to the gate-driving fields
  (`CKR_IsComplete__c`, and `CKR_Required__c`, `CKR_Completed__c`,
  `CKR_CompletedBy__c`, `CKR_CompletedOn__c` on items). The service derives
  them; see [system-mode sites](#user-mode-and-system-mode-sites).
- `CKR_ReadOnly` has View All on every CheckR object it covers. Assign it only
  to users who may see all checklists and audit history.
- `CKR_ReadOnly` deliberately grants no Apex class access, so a user who holds
  only `CKR_ReadOnly` cannot load `ckrChecklistViewer`. The viewer's
  `canEditItems` flag comes from the user's access to the _parent_ record (and
  the template's completion access mode), not from CheckR object rights. A
  read-only user who can edit the parent Account would therefore see edit
  controls whose saves then fail on user-mode DML. Granting the controller
  safely first needs the permission service to also require edit rights on
  `CKR_ChecklistInstanceItem__c`. Until then, read-only users review
  checklists through reports and list views. `npm run test:permission-sets` pins
  this decision.
- Required and master-detail fields cannot carry field permissions in
  Salesforce, so they are always accessible to users with object access.

Field-level grants and Apex class access are listed per set in
[architecture: permission sets](architecture.md#permission-sets).

## Org-wide defaults

| Object                            | Internal             | External             |
| --------------------------------- | -------------------- | -------------------- |
| `CKR_ChecklistTemplate__c`        | `ReadWrite`          | `Private`            |
| `CKR_ChecklistTemplateVersion__c` | `ControlledByParent` | `ControlledByParent` |
| `CKR_ChecklistTemplateItem__c`    | `ControlledByParent` | `ControlledByParent` |
| `CKR_ChecklistGateRule__c`        | `ControlledByParent` | `ControlledByParent` |
| `CKR_ChecklistInstance__c`        | `ReadWrite`          | `Private`            |
| `CKR_ChecklistInstanceItem__c`    | `ControlledByParent` | `ControlledByParent` |
| `CKR_ChecklistAuditEvent__c`      | `ControlledByParent` | `ControlledByParent` |
| `CKR_GateBypassEvent__c`          | `Private`            | `Private`            |

The sharing models are also stated per object in the
[object model](object-model.md), where the test checks them against metadata.

**Why Template and Instance are `ReadWrite`.** Checklists are
collaborative work on business records that users can already see. Record
visibility is not where CheckR narrows access:

- **Object access** comes from the permission sets above. A user without
  `CKR_Admin` cannot edit templates, versions, items, or gate rules even though
  the template OWD is `ReadWrite`. A user without a CheckR permission set has no
  object access at all.
- **Completion access** is narrowed per template version by
  `CKR_ChecklistTemplateVersion__c.CKR_CompletionAccessMode__c`: `ReadAccess`
  or `EditAccess` on the parent record, or `CustomPermission`, in which case the
  user must hold the custom permission named in
  `CKR_CustomPermissionDeveloperName__c`.
- **Published versions are immutable**, so a `ReadWrite` OWD does not let
  anyone change what a published checklist requires.

Making Template or Instance `Private` would need sharing that follows each
instance's parent record. Salesforce can only do that through master-detail or
custom Apex sharing per parent object, and CheckR attaches to any supported
object through a text Id (`CKR_ParentRecordId__c`), so it cannot be done
generically. Orgs that need tighter instance visibility can lower the OWD and
add their own sharing rules; CheckR's queries run in user mode and will respect
them.

`CKR_GateBypassEvent__c` is `Private` because bypass history is an operator
concern. `CKR_Admin` reads it through View All; `CKR_GateBypass` holders see
only the events they own.

## User mode and system-mode sites

All SOQL and DML runs in user mode by default (`AccessLevel.USER_MODE` in
`CKR_SelectorBase` and `CKR_DefaultDmlGateway`), so object, field, and
sharing access apply. User-mode updates send only the fields the flow changes.

There are five documented system-mode sites. The full list, with the classes
involved, is in [architecture: system-mode exceptions](architecture.md#system-mode-exceptions):

1. gate evaluation reads;
2. audit and bypass event writes;
3. derived `CKR_IsComplete__c` writes;
4. gate-driving item field writes;
5. audit retention reads before deletes.

Operational reports and the dashboard add no Apex and run as the viewer.

### Why the gate reads in system mode

A gate is a control on the parent object's save. It must block every user who
edits the protected field, including users with no CheckR permission set who
cannot see the gate rules or the checklist. If the gate read rules and
instances in user mode, a user without access would silently skip the gate.
The gate classes are `inherited sharing` and read only configuration and
completion state; they never return rule or checklist data to the user beyond
the rule's error message.

## Permission tests

Tests that verify Salesforce permissions, CRUD, FLS, or sharing run inside
`System.runAs` as a previously inserted user with the permissions under test.
Admin-context wiring tests can use the existing running user. Pure logic and
tests that stub selectors or access gateways exercise in-memory decisions and
can run without `System.runAs`.

## Gate bypass

Bypass is off by default. A blocked save passes only when the running user
holds the `CKR_BypassGate` custom permission (through `CKR_GateBypass`), or
when the effective `CKR_Settings__c.CKR_BypassGate__c` hierarchy value is true
for the org, the user's profile, or the user. The custom permission wins when
both apply.

Every bypassed save writes a `CKR_GateBypassEvent__c` row in the same
transaction, recording the actor, record, object, first blocking rule, source,
time, and original error. If the audit insert fails, the save fails, so there
are no unaudited bypasses. Saves that are not blocked write nothing.

Installing for **Admins Only** also grants `CKR_BypassGate` and
`CKR_Audit_Maintenance` to the System Administrator profile. Remove both after
every install and upgrade; see
[installation](installation.md#remove-the-admin-profiles-bypass-and-audit-maintenance).

Assign `CKR_GateBypass` only to trusted integration identities and operators
responsible for migrations or incident fixes, and remove temporary grants
promptly. Limit management of the `CKR_Settings__c` hierarchy custom setting
to trusted Salesforce administrators. `CKR_Admin` can read all bypass events
without being able to bypass. See [gate bypass operations](gate-bypass.md).

## Audit history

Audit and bypass events are append-only. Updates and deletes are rejected
without the `CKR_Audit_Maintenance` custom permission, including system-mode
DML. Deleting an instance or item that has audit history is blocked for
everyone else, so master-detail cascade cannot silently remove hidden history.
Gate rules, versions, and templates referenced by bypass events cannot be
deleted while those events exist.

`CKR_Admin`, `CKR_User`, `CKR_ReadOnly`, and `CKR_GateBypass` grant no history
writes. `CKR_AuditMaintenance` grants audit edit/delete and view/modify-all for
approved, exported maintenance, and permits deleting audited instances with
their history. Remove it promptly.

Metadata administrators can grant maintenance or deactivate the guards, so
this is not a tamper-proof external audit log. Export history to an external
store if you need one. See [records and retention](records-and-retention.md).

## Reporting a vulnerability

Do not open a public issue. Follow the private reporting process in
[`SECURITY.md`](../SECURITY.md).
