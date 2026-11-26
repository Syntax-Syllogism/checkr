# CheckR for Salesforce

CheckR attaches versioned checklists to Salesforce records and can block a
record's save until the required checklist work is done. It is built for
implementation handoffs, readiness checks, compliance steps, QA gates, and
onboarding: any process where a record should not move on until a list of
things has been checked off. It does not use the standard `Task` object.

The public repository is
[Syntax-Syllogism/checkr](https://github.com/Syntax-Syllogism/checkr).

## Status

CheckR 0.1.3 is a released package version and installs in production,
sandboxes, and scratch orgs. Until 1.0, the data model and Apex APIs may still
change between minor versions; the [changelog](CHANGELOG.md) lists each version
and its changes. Feedback is welcome; see [Feedback](#feedback).

## Requirements

- An Enterprise, Unlimited, Performance, or Developer Edition org, or a sandbox
  or scratch org of one.
- A user who can install packages and assign permission sets.
- A before-save trigger shim, written in your org, for each object whose saves
  you want to gate. See [Enable an object](#2-enable-an-object).

## What it does

- **Templates per object.** A checklist template belongs to one object. Its
  versions move from `Draft` to `Published` to `Historical`, and a published
  version is immutable. Publishing is a service action; see
  [template version publishing](docs/template-version-publishing.md).
- **Instances snapshot a version.** A checklist instance on a record copies the
  published version it was created from. A record can have several instances,
  shown in an accordion on the record page.
- **Items.** Every item is a checkbox. An item can require an explanation,
  entered as text or chosen from a picklist. Users can add and remove ad hoc
  items on an instance. Only required template items count toward completion.
- **Ownership and assignment.** A checklist instance is owned through its
  standard `OwnerId`. Each item can be assigned to one user
  (`CKR_AssigneeUser__c`).
- **Save gates.** Gate rules on a template version block a record update while
  the required items are incomplete. A record with an instance is judged by that
  instance's version; a record without one is judged by the Published version.
  Inserts are not gated. Gates run in Apex before-save triggers, not Flow.
  Action types are `AnyFieldValueChange` and `SpecificFieldValueChange`.
- **Audited bypass.** Gate bypass is off by default. A blocked save passes only
  through the `CKR_BypassGate` custom permission or the `CKR_Settings__c`
  hierarchy switch, and every bypass is recorded; see
  [gate bypass operations](docs/gate-bypass.md).
- **Append-only history.** Audit and bypass events cannot be edited or deleted
  without `CKR_Audit_Maintenance`; see
  [records and retention](docs/records-and-retention.md).
- **Reports.** A `CheckR Operations` report folder and dashboard cover open
  checklists, recent audit activity, and bypasses; see
  [operational reporting](docs/admin-guide/10-reports.md#operational-reporting).

End users work checklists in the `ckrChecklistViewer` record-page component and
attach them with the `ckrChecklistCreateAction` quick action. Admins manage
templates, items, and gate rules as ordinary records. The objects and fields are
in the [object model](docs/object-model.md).

## Install

CheckR installs as the unlocked package `checkr`, with no namespace. The
current version is 0.1.3 (`04tfj000000nuPFAAY`); each version's `04t` ID is in
the [changelog](CHANGELOG.md). Open the install link while logged in to the
target org:

```text
https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfj000000nuPFAAY
```

For a sandbox, use `test.salesforce.com` in place of `login.salesforce.com`.

or install with the CLI:

```bash
sf package install --package 04tfj000000nuPFAAY --target-org <your-org-alias> --security-type AdminsOnly --wait 20 --json
```

Installing for admins grants the System Administrator profile gate bypass and
audit maintenance; remove both right away, as the
[installation guide](docs/installation.md#remove-the-admin-profiles-bypass-and-audit-maintenance)
describes.

The [installation guide](docs/installation.md) covers prerequisites, permission
sets, enabling an object with your own trigger shim and its test, upgrades,
uninstalling, and troubleshooting. The [admin guide](docs/admin-guide/README.md)
walks through setup with screenshots. To work on CheckR itself, deploy from
source as described in [Development](#development).

## Quick Start

### 1. Assign permission sets

| Permission set         | Grants                                                                                                                                                                                   |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CKR_Admin`            | Template, version, item, and gate rule administration; the Publish Version action; read-only audit and bypass history.                                                                   |
| `CKR_User`             | Create checklist instances, work and assign items, add and remove ad hoc items, and use the viewer and create action. Sharing applies.                                                   |
| `CKR_ReadOnly`         | Read access with View All to every CheckR object except gate bypass events. No Apex class access, so it cannot load the record-page viewer on its own; see [security](docs/security.md). |
| `CKR_GateBypass`       | Audited gate bypass for data loads and incident fixes. Assign it only for the window that needs it; see [security](docs/security.md#gate-bypass).                                        |
| `CKR_AuditMaintenance` | Temporary edit and delete on audit and bypass history, for approved maintenance only. Export first; see [records and retention](docs/records-and-retention.md).                          |

Give `CKR_Admin` to implementers and template managers and `CKR_User` to people
who work checklists. `CKR_GateBypass` and `CKR_AuditMaintenance` are operational
and never part of routine assignments.

### 2. Enable an object

An object takes part in CheckR when it has an active `CKR_SupportedObject__mdt`
record. Set `CKR_ObjectApiName__c`, `CKR_ObjectLabel__c`,
`CKR_ObjectLabelPlural__c`, `CKR_Active__c`, and, for gated objects,
`CKR_SupportsGates__c`.

Gates are enforced only once a before-save trigger shim on the object calls
`CKR_ChecklistTriggerGateway.handleBefore`. The reference Account shim is
[`CKR_AccountTrigger`](sfdx-source/reference/main/triggers/CKR_AccountTrigger.trigger):

```apex
trigger CKR_AccountTrigger on Account(before insert, before update) {
  CKR_ChecklistTriggerGateway.handleBefore(
    'Account',
    Trigger.oldMap,
    Trigger.newMap
  );
}
```

Each shim needs test coverage in your org before a production deployment; see
[platform constraints](docs/platform-constraints.md#trigger-shim-per-object).

### 3. Place the UI

Add `ckrChecklistViewer` to the object's Lightning record page and
`ckrChecklistCreateAction` as a screen quick action on the same object.

### 4. Build and publish a template

Create a `CKR_ChecklistTemplate__c`, a draft `CKR_ChecklistTemplateVersion__c`,
its `CKR_ChecklistTemplateItem__c` rows, and optionally
`CKR_ChecklistGateRule__c` rows. Then publish the version and attach checklists
to records with the quick action. If users are blocked by a gate, use the
[gate-blocking-saves runbook](docs/runbooks/gate-blocking-saves.md).

## Development

Local development needs Node 22+, [afmt](https://github.com/xixiaofinland/afmt)
1.0.0, and the [AER](https://aertest.com) binary pinned in
`scripts/gate.mjs`. AER needs a license in `AER_LICENSE_KEY` to run
the full Apex suite; without one it stops at 100 test methods. Metadata targets API 67.0.

```bash
npm ci                                   # dependencies and commit hooks
npm test                                 # full no-org suite
node scripts/gate.mjs                    # npm test, Code Analyzer when installed, and AER Apex tests
npm run test:apex                        # AER Apex tests only
npm run dev:lwc:local -- --name ckrChecklistViewer   # LWC preview without an org
npm run org:evidence -- --scenario <name> --org <alias>   # real-org evidence
sf project deploy start --target-org <alias> --source-dir sfdx-source/checkr --source-dir sfdx-source/reference --json   # source deploy
```

[Testing, gate, and CI](docs/testing.md) describes each command, the hooks, and
the toolchain pins. The local AER preview runs as `CKR_Admin` against an empty
database; set `useMockData` on `ckrChecklistViewer` to render fixture data. For
record-page and quick-action checks, use Live Preview against an org with
`npm run dev:lwc:checkr -- --target-org <alias>`; the scratch definition in
`config/project-scratch-def.json` enables it. See
[CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Documentation

The [documentation index](docs/README.md) lists every guide: architecture,
security, object model, platform constraints, the admin guide, runbooks, and
org evidence. How versions are released is in the
[release guide](docs/release.md).

## Feedback

The most useful feedback is about missing checklist or gate behavior,
deployment friction, record-page usability, gaps in permissions, auditability,
or reporting, and extension points that should be cleaner. Open an issue on the
public repository. Report security issues as described in
[SECURITY.md](SECURITY.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Participation is covered by the
[Code of Conduct](CODE_OF_CONDUCT.md).

## License

CheckR is released under the [MIT License](LICENSE).
