---
title: "Platform constraints"
---

The Salesforce and tooling limits an admin or developer will run into with
CheckR, and how CheckR behaves at each one. Object details are in the
[object model](object-model.md); gate internals are in
[architecture](architecture.md#template-version-lifecycle-and-gate-evaluation).

## Gate cost per transaction

The gate runs inside the parent object's `before update` trigger, so its cost
is charged to the user's save. The selector loads gate rules and matching
instances in bulk for the whole trigger batch, not per record.

The [`bulk-200` evidence run](evidence/2026-10-20-bulk-200-b3c31cf/README.md)
updated 200 Accounts in one `Database.update(records, false)` against three
active rules on separate Published versions (100 records allowed, 100
blocked). The gate used **2 SOQL queries and 78 ms CPU** for the batch; the
scenario's budget is 6 queries including partial-save retries. See
[evidence scenarios](evidence/scenarios.md#bulk-200).

Budget for this in addition to your own triggers, flows, and validation on the
same object. The cost grows with the number of matching rules and instances,
not the number of templates in the org. Bypassed saves add one bulk system-mode
insert of `CKR_GateBypassEvent__c` rows.

## One instance per record per template

A record can have at most one checklist instance per template, across all
versions. The instance service builds `CKR_UniqueKey__c` as
`<parentRecordId>|<templateId>` and refuses to create a second instance; the
field is a unique external Id, so concurrent creates also fail at the database.
To run a checklist again, complete or delete the existing instance (deletion
is blocked once it has audit history; see
[records and retention](records-and-retention.md)).

Publishing a new version never migrates existing instances. An existing
instance stays on its own version's items and gate rules.

## Inserts are not gated

Gates judge updates only. In `before insert` the record has no
Id and `Trigger.newMap` is null, and a checklist can only be attached to a
persisted record, so there is nothing to judge. `CKR_ChecklistTriggerGateway`
returns early on insert. A record created directly with a protected field
value (for example, inserted with `Rating = Hot`) is saved; the gate applies
to its first later update of that field.

If you need to restrict creation, use a validation rule, a record-type or
page-layout control, or your own trigger. The `insert-gating` evidence
scenario and `CKR_InsertGatingIT` pin this behavior.

## Trigger shim per object

Admins can configure templates and gate rules for any supported object, but
**no gate fires until a trigger shim is deployed for that object**. CheckR
cannot ship one trigger for every object. Each shim is a few lines that pass
the batch to `CKR_ChecklistTriggerGateway`, as in the reference
`CKR_AccountTrigger` (`sfdx-source/reference`):

```apex
trigger CKR_AccountTrigger on Account(before insert, before update) {
  CKR_ChecklistTriggerGateway.handleBefore(
    'Account',
    Trigger.oldMap,
    Trigger.newMap
  );
}
```

- Register the object in `CKR_SupportedObject__mdt` with
  `CKR_SupportsGates__c` checked.
- The shim is subscriber code. Salesforce requires every trigger to have some
  test coverage before a production deployment, so add a test in your org that
  updates a record of that object and asserts a gated save is blocked. The
  reference `CKR_InsertGatingIT` and `CKR_GateBypassIT` classes show the shape.
- Keep the shim free of logic, and consider its order relative to your other
  triggers on the object; Salesforce does not guarantee trigger order.
- A gate blocks with `addError` on the record. With
  `Database.update(records, false)` only the blocked records fail.

## Gate values compare as strings

`SpecificFieldValueChange` rules compare the new field value as
`String.valueOf(value)` against the target values, exactly and
case-sensitively. Target values are trimmed; the field value is not. This works
for text and picklist fields when the target matches the stored API value. It
can mismatch for:

- picklist values typed with different casing than the API value;
- numbers (`5` versus `5.0`), dates, and datetimes, whose string form depends
  on Apex formatting;
- checkboxes, which compare as `true` or `false`.

`AnyFieldValueChange` is unaffected: it blocks on any change of the string
form. Typed comparison is planned future work.

## Multi-value targets

`CKR_TargetValueSet__c` holds several target values separated by `;`, `,`, or
newline. Blank entries are ignored and each value is trimmed. A value cannot
itself contain one of those separators. `CKR_TargetValue__c` holds one value
and may be used together with the set.

## AER versus a real org

The no-org Apex tier runs in [AER](https://aertest.com), an in-memory Apex
runtime. It is fast and needs no org, but it is not Salesforce:

- CI is capped at **100 test methods** because the AER license does not cover
  it. `scripts/aer-capped.mjs` runs the newest test classes that fit; the local
  gate runs everything under the developer license (`AER_LICENSE_KEY`; never
  commit it). See [testing](testing.md#ci-githubworkflowsciyml).
- Tests run with `-p CKR_Admin`; without it, user-mode queries fail because
  field-level security hides every field.
- AER treats master-detail fields as FLS-gated, unlike Salesforce.
- Sharing rules, `UserRecordAccess` in user mode, and
  `countQueryWithBinds(AccessLevel)` cannot be confirmed in AER.
- Dynamic `PermissionSetAssignment` does not make
  `FeatureManagement.checkPermission` return true, so the custom-permission
  bypass path is proven in a real org.

Behavior AER cannot confirm is covered by `npm run org:evidence`; see
[org evidence](evidence/README.md) and
[architecture: test tiers](architecture.md#test-tiers).
