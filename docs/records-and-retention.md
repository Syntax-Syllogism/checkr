---
title: "Records and retention"
---

`CKR_ChecklistAuditEvent__c` records checklist activity, actor, time and changes.
`CKR_GateBypassEvent__c` records blocked saves allowed by an operational bypass.
Templates, versions, instances and items are working data; Published and
Historical configuration also has lifecycle protections.

## Append-only history

Before-update and before-delete triggers reject audit and bypass changes with:
“CheckR audit records are append-only. Ask an administrator with CheckR Audit
Maintenance.” Inserts by application services still use the system DML gateway.
Routine CheckR sets grant read access only; they cannot create, edit or delete
history. `CKR_GateBypass` grants bypass, not audit mutation rights.

Assign `CKR_AuditMaintenance` only temporarily to a trusted operator after
exporting the affected history. It grants `CKR_Audit_Maintenance` plus edit,
delete, and view/modify-all on audit and bypass events. Instance deletion
additionally needs ordinary instance permissions. Remove the assignment immediately afterwards.
This is an application control, not an external tamper-proof ledger: metadata
administrators can disable triggers or grant maintenance themselves.

## Instance and parent deletion

Audit events are master-detail children of checklist instances. Salesforce
cascade deletion does not invoke child delete triggers, so an instance
before-delete guard checks all its audit children in one system-mode aggregate
query. Without maintenance, deleting any audited instance fails, even if its
history is hidden from the actor. Instances without audit events remain
deletable. With maintenance, instance deletion cascades to its audit events and
items: export both first. Bypass events are independent of instances and survive
instance deletion. The bypass event's gate-rule lookup uses Restrict: a referenced
rule cannot be deleted, directly or through a template/version cascade, while
bypass history exists. This also applies to maintainers. Export the rule and
linked history first; a maintainer must explicitly delete the linked bypass
events before deleting otherwise deletable configuration. Rules without bypass
history retain their existing lifecycle deletion behavior.
Deleting an audited checklist item also requires maintenance. An item
before-delete guard checks all linked audit events in one system-mode aggregate
query and rejects deletion before Salesforce can clear the
`CKR_ChecklistInstanceItem__c` SetNull lookup. This includes ad hoc items created
through the viewer, which already have an `AdHocItemAdded` event: ordinary users
can edit them but must ask a maintainer to remove them. Items without linked
audit events remain deletable. With maintenance, item deletion retains the audit
event and clears its item lookup; export the item and linked history first.
Instance and item deletion behaviors are verified by the five passing Apex methods in the
[2026-10-20 Salesforce evidence run](evidence/2026-10-20-audit-integrity-4e93bc7/README.md).

`CKR_ParentRecordId__c` is Text(18), not a relationship. Deleting an Account or
other parent leaves orphaned instances and history; there is no automatic
cascade or cleanup. Keep the parent ID and object API name in archives so these
records remain interpretable. Template and version lookups on instances use
Restrict, preventing template deletion from bypassing this guard.

## Retention and sizing

CheckR never automatically purges history. Suggested operational policy: retain
audit and bypass events for at least as long as the related parent business
records, including any required archive period. The org owner must choose and
document the actual period based on its obligations; parent deletion does not
start an automatic purge. Retain working instances until their history has been
archived and approved for deletion.

Budget approximately 2 KB of Salesforce data storage per event: 100,000 events
are roughly 200 MB; one million are roughly 2 GB. Include checklist instances,
items and other org data in capacity planning and verify actual usage in Setup.

## Manual export and archive

1. Select a cutoff and scope approved by the data owner. Export both audit
   objects with Data Loader. A report export can serve only if it exposes every
   needed field; the shipped audit and bypass reports cover just the last 30
   days, so widen a clone first (see the [admin guide](admin-guide/10-reports.md#operational-reporting)).
2. Include IDs, instance and item IDs, actor, time, event/source, old/new values,
   details, gate rule, and parent ID/object. Export related instances, items and
   relevant template/version/rule configuration to preserve context. Bypass
   events already carry their parent ID and object directly.
3. Validate row counts, required fields and a sample of joins; store exports in
   the organization's access-controlled archive with its retention policy.
   Confirm the archive can be read before deleting anything.
4. Temporarily assign maintenance, delete only the verified exported IDs, and
   retain an external record of scope, counts, approval, operator and time.
   Deleting an instance removes all its audit children, including newer ones:
   prefer explicit event IDs when purging by cutoff.
5. Reconcile remaining counts and remove maintenance. No archiving job is
   included. Ordinary users should never receive this permission for cleanup.

See [security operations](security.md) and the `audit-integrity`
[org evidence scenario](evidence/scenarios.md).
