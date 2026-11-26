# Publishing checklist template versions

Use the **Publish Version** action on a Checklist Template Version record in
CheckR. The supplied version record page includes the action; if you use a custom
page, add `CKR_ChecklistTemplateVersion__c.CKR_PublishVersion` to its actions.
The publisher needs `CKR_Admin` (or equivalent object, field, and controller
access).

1. Create a **Draft** version under the template.
2. Configure its items and active gate rules. Add at least one item.
3. Select **Publish Version**. The version becomes **Published**, its publisher
   and timestamp are recorded, the previous Published version becomes
   **Historical**, and the template's current version pointer changes together.

A failed publish rolls back all those changes. Direct UI/API status changes to
Published or Historical are rejected. Published and Historical versions and their
items and rules cannot be edited; configure a new Draft for future changes.
Publishing an empty or already published version is rejected.

Existing checklist instances retain their snapshot and version. For example,
a completed v1 checklist still satisfies v1 gates after v2 publishes. A record
without an instance uses the Published version's gates. There is still only one
instance per parent record and template; publishing does not migrate instances.

Record inserts remain ungated. Gates apply on protected field changes in
updates after a record has an Id and can have a checklist attached. Enforcement
requires an object trigger shim, including the supplied Account reference shim.
