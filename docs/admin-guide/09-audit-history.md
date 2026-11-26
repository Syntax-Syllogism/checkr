---
title: "Audit history and retention"
---

CheckR keeps two kinds of history.

| Object                | Written when                                                                                                    | Where to see it                                                                                                     |
| --------------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Checklist Audit Event | A user completes or uncompletes an item, changes an explanation or assignee, or adds or removes an ad hoc item. | The audit report. Add the **Checklist Audit Events** related list to the instance layout to see them per checklist. |
| Gate Bypass Event     | A bypass lets through a save that a gate would have blocked.                                                    | The bypass report, or a SOQL query on `CKR_GateBypassEvent__c` ([gate bypass operations](../gate-bypass.md)).       |

Each audit event has the actor, time, event type, item, and old and new
values. Blocked saves that were not bypassed are **not** recorded anywhere.

## Append-only

Nobody edits or deletes history in normal operation. Updates and deletes fail
with "CheckR audit records are append-only. Ask an administrator with CheckR
Audit Maintenance." Deleting a checklist instance or item that has audit
history is blocked for the same reason. A gate rule, version, or template that
a bypass event points at cannot be deleted either.

When a deletion is approved (an archive, or a record moving to a new version):

1. Export the affected audit events, bypass events, instances, and items with
   Data Loader.
2. Assign `CKR_AuditMaintenance` to a trusted operator.
3. Make the deletion.
4. Remove the assignment.

## Retention

CheckR never purges history. Keep it at least as long as the business records
it relates to, and plan about 2 KB of data storage per event. Deleting a parent
record leaves its checklists and history in place.

The full policy, sizing, and export steps are in
[records and retention](../records-and-retention.md).
