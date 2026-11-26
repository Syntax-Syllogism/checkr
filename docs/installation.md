---
title: "Installation, upgrade, and uninstall"
---

CheckR ships as the unlocked package `checkr`, with no namespace. This guide
covers installing it, enabling an object, upgrading, and removing it. For the
admin walkthrough with screenshots, see the [admin guide](admin-guide/README.md).
For how versions are built, see [packaging](packaging.md).

> **Beta.** CheckR versions are betas until one is promoted. Salesforce installs
> beta (unpromoted) package versions only in scratch orgs and sandboxes, not in
> production.

## Prerequisites

- **Edition:** Enterprise, Unlimited, Performance, or Developer Edition, or a
  sandbox or scratch org of one. CheckR needs Apex triggers and custom metadata,
  so Professional Edition is not supported.
- **My Domain** deployed, which every org now has, and **Lightning Experience**
  for the record-page viewer and quick action.
- An org on a Salesforce release that supports **API 67.0**.
- The installing user needs the **Download AppExchange Packages** permission
  (System Administrators have it).

## Install

Every beta has a subscriber package version ID (`04t…`). It is recorded in
`docs/evidence/releases/<version>/version.json` and in the
[changelog](../CHANGELOG.md).

**By link.** Open the install URL in the target org and choose **Install for
Admins Only**:

```text
https://test.salesforce.com/packaging/installPackage.apexp?p0=<04t>
```

The recorded beta URL uses `test.salesforce.com` for test orgs. For a scratch
org, replace the host with that org's My Domain URL if needed. Beta versions
cannot be installed in production or standalone Developer Edition orgs.

**With the CLI:**

```bash
sf package install --package <04t> --target-org <alias> \
  --security-type AdminsOnly --wait 20 --publish-wait 10 --no-prompt --json
sf package installed list --target-org <alias> --json
```

The second command should list `checkr` with the version you installed.

### Remove the admin profile's bypass and audit maintenance

Installing for **Admins Only** gives the System Administrator profile every
custom permission in the package, including **Bypass CheckR save gates**
(`CKR_BypassGate`) and **CheckR Audit Maintenance** (`CKR_Audit_Maintenance`).
Until you remove them, every System Administrator's blocked saves go through
(each is recorded as a Gate Bypass Event) and every System Administrator can
edit and delete audit history. Remove both right after installing.

In Setup, open **Profiles → System Administrator → Enabled Custom Permissions →
Edit**, remove both, and save (confirm the labels in your org). Or with the CLI,
list the profile grants and delete each row it returns:

```bash
sf data query --target-org <alias> --json --query "SELECT Id, Parent.Profile.Name FROM SetupEntityAccess WHERE Parent.IsOwnedByProfile = true AND SetupEntityId IN (SELECT Id FROM CustomPermission WHERE DeveloperName IN ('CKR_BypassGate', 'CKR_Audit_Maintenance'))"
sf data delete record --target-org <alias> --sobject SetupEntityAccess --record-id <0J0…> --json
```

Run the query again; it should return no rows. Grant bypass and audit
maintenance only through `CKR_GateBypass` and `CKR_AuditMaintenance`, for a
limited time (see [gate bypass](gate-bypass.md)).

The package contains every `CKR_` object, the Apex services and the trigger
gateway, the three LWCs (`ckrChecklistViewer`, `ckrChecklistCreateAction`,
`ckrPublishTemplateVersion`), the five permission sets, reports and the
`CheckR Operations` dashboard, and the `CKR_SupportedObject__mdt` type with an
active Account record. It contains **no trigger**, so no gate fires until you
deploy a shim (see [Enable an object](#enable-an-object)).

## Permission sets

| Permission set         | Who gets it                                                                        |
| ---------------------- | ---------------------------------------------------------------------------------- |
| `CKR_Admin`            | Implementers and template managers. Assign it to yourself first.                   |
| `CKR_User`             | People who create and work checklists.                                             |
| `CKR_ReadOnly`         | Auditors and reporting users who only read CheckR data. It excludes bypass events. |
| `CKR_GateBypass`       | Nobody by default. Assign only for a data load or incident window, then remove it. |
| `CKR_AuditMaintenance` | Nobody by default. Approved audit maintenance only, after an export.               |

```bash
sf org assign permset --name CKR_Admin --target-org <alias> --json
```

See [security](security.md) for what each set grants, and
[gate bypass](gate-bypass.md) and [records and retention](records-and-retention.md)
for the two operational sets.

## Enable an object

An object takes part in CheckR when it has an active `CKR_SupportedObject__mdt`
record **and** a trigger shim. Account's record ships in the package; Account
still needs a shim.

### 1. Supported-object record

In Setup, open **Custom Metadata Types → Supported Object → Manage
Records → New** (confirm the label in your org), or deploy a record such as
`customMetadata/CKR_SupportedObject.Opportunity.md-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<CustomMetadata
  xmlns="http://soap.sforce.com/2006/04/metadata"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
>
    <label>Opportunity</label>
    <protected>false</protected>
    <values>
        <field>CKR_Active__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>CKR_ObjectApiName__c</field>
        <value xsi:type="xsd:string">Opportunity</value>
    </values>
    <values>
        <field>CKR_ObjectLabel__c</field>
        <value xsi:type="xsd:string">Opportunity</value>
    </values>
    <values>
        <field>CKR_ObjectLabelPlural__c</field>
        <value xsi:type="xsd:string">Opportunities</value>
    </values>
    <values>
        <field>CKR_SupportsGates__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
</CustomMetadata>
```

### 2. Trigger shim

The shim is your code, not the package's. Keep it free of logic:

```apex
trigger OpportunityChecklistTrigger on Opportunity(
  before insert,
  before update
) {
  CKR_ChecklistTriggerGateway.handleBefore(
    'Opportunity',
    Trigger.oldMap,
    Trigger.newMap
  );
}
```

Record inserts are not gated; the `before insert` event is there so the shim
does not need changing if that ever changes. See
[platform constraints](platform-constraints.md#trigger-shim-per-object) for
trigger order and partial-save behavior.

### 3. Shim test

Production deployments need coverage for every trigger. Test data has no
published template, so the gate lets every save through and the test only has
to fire the shim:

```apex
@IsTest
private class OpportunityChecklistTriggerTest {
  @IsTest
  static void savesPassThroughTheShimWithoutPublishedTemplates() {
    Opportunity record = new Opportunity(
      Name = 'CheckR shim',
      StageName = 'Prospecting',
      CloseDate = Date.today()
    );
    insert record;

    record.StageName = 'Qualification';
    update record;

    System.Assert.areEqual(
      'Qualification',
      [SELECT StageName FROM Opportunity WHERE Id = :record.Id].StageName,
      'With no published template the gate must allow the save'
    );
  }
}
```

Add your own required fields and validation-rule data to the record. To also
prove a block, the reference `CKR_InsertGatingIT` and `CKR_GateBypassIT`
classes in `sfdx-source/reference` show how to seed and publish a gated
template in a test.

### 4. Place the UI

Add `ckrChecklistViewer` to the object's Lightning record page and
`ckrChecklistCreateAction` as a screen quick action on the same object.

## First template

Follow the admin guide from
[authoring a template](admin-guide/04-authoring-a-template.md) through
[gate rules](admin-guide/05-gate-rules.md),
[publishing](admin-guide/06-publishing-and-new-versions.md), and
[working a checklist](admin-guide/07-working-a-checklist.md).

## Upgrade

Install the newer `04t` over the old one, with the same link or command:

```bash
sf package install --package <new 04t> --target-org <alias> \
  --security-type AdminsOnly --upgrade-type Mixed --wait 20 --no-prompt --json
```

- **What changes:** packaged metadata is replaced with the new version. Records,
  permission set assignments, your supported-object records, and your trigger
  shims stay. With `--upgrade-type Mixed`, components the new version removed
  are deleted when that is safe and deprecated otherwise. Read the
  [changelog](../CHANGELOG.md) entry for the version first.
- **Gates during the upgrade:** your shims stay active, so gates keep enforcing
  throughout. Saves that run while the install replaces Apex may fail and need
  a retry. Upgrade in a quiet window, and do not bulk-load during it.
- **Existing checklists** keep the template version they snapshotted. Published
  and Historical versions stay immutable.
- **After the upgrade:** run `sf package installed list` and confirm the version,
  run the [admin profile query](#remove-the-admin-profiles-bypass-and-audit-maintenance) again and
  remove any rows it returns,
  run your shim tests (`sf apex run test --class-names <ShimTest> --json`), and
  save one record that a published gate should block and one it should allow.

The `install-upgrade` [evidence scenario](evidence/scenarios.md#install-upgrade)
checks that templates, versions, instances, items and audit events survive an
upgrade and that the gate still blocks and passes.

## Uninstall

Uninstalling deletes every CheckR object and its records, including audit and
bypass history. Export what you need to keep first; see
[records and retention](records-and-retention.md).

Salesforce blocks the uninstall while your own metadata depends on the
package. Remove things in this order:

1. Delete your trigger shims and their test classes. They reference
   `CKR_ChecklistTriggerGateway`, so they block the uninstall.
2. Remove `ckrChecklistViewer` and `ckrChecklistCreateAction` from record pages
   and layouts.
3. Delete the `CKR_SupportedObject__mdt` records you created, and any reports,
   flows or Apex of your own that reference `CKR_` objects or classes.
4. Remove the CheckR permission set assignments.
5. Uninstall in **Setup → Installed Packages → checkr → Uninstall**, or:

   ```bash
   sf package uninstall --package <04t> --target-org <alias> --wait 20 --json
   ```

This order has not yet been run against an installed beta. If the platform
blocks a step, Setup lists the blocking components; remove them and retry.

## Troubleshooting

| Symptom                                               | Cause and fix                                                                                                                                                                            |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Install fails in production                           | Beta versions install only in sandboxes and scratch orgs. Wait for a promoted version.                                                                                                   |
| Templates and gate rules exist but nothing is blocked | The object has no trigger shim, its supported-object record is inactive, or `CKR_SupportsGates__c` is off.                                                                               |
| System Administrators' saves are never blocked        | The install granted their profile `CKR_BypassGate`. Remove it; see [the post-install step](#remove-the-admin-profiles-bypass-and-audit-maintenance).                                     |
| A retired (inactive) template still blocks saves      | Unchecking Active hides a template from **New Checklist** only. Publish a version with no rules; see the [admin guide](admin-guide/06-publishing-and-new-versions.md#retire-a-template). |
| Users can't save a record                             | A gate is doing its job, or a rule is wrong. Follow the [gate-blocking-saves runbook](runbooks/gate-blocking-saves.md).                                                                  |
| The viewer shows nothing or an access error           | The user lacks `CKR_User`, or cannot see the parent record. `CKR_Admin` and `CKR_ReadOnly` do not grant the viewer's Apex classes.                                                       |
| Deploying a shim fails on coverage                    | Deploy the shim with its test class and run that test.                                                                                                                                   |
| Uninstall is blocked                                  | Your metadata still references the package. Follow the [uninstall](#uninstall) order; Setup lists the blocking components.                                                               |
| Upgrade fails with a component error                  | Read the error in `sf package install report --request-id <0Hf> --json`. Your metadata may reference a component the version removed.                                                    |

See the admin guide [troubleshooting chapter](admin-guide/11-troubleshooting.md)
for more.
