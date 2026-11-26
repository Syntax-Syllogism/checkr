samples and reference metadata not included in the package

Contents:

- `classes/CheckrSmokeSeed.cls`
  Sample smoke-seed helper for creating demo Accounts, templates, versions,
  checklist items, gate rules, and checklist instances.
- `classes/CheckrSmokeUserSeed.cls`
  Setup-data smoke-seed helper for creating test users and assigning smoke
  permission sets in a separate transaction. The admin smoke user is created
  on a `Salesforce` user license profile; other smoke users are created on
  `Salesforce Platform` profiles.
- `triggers/AccountTrigger.trigger`
  Sample thin trigger shim that wires Account before-save events into
  `CKR_ChecklistTriggerGateway`.
- `user/customPermissions/CKR_Smoke_Compliance_Update.customPermission-meta.xml`
  Reference custom permission used by compliance completion mode smoke tests.
- `user/permissionsets/CKR_Smoke_Compliance.permissionset-meta.xml`
  Reference permission set that grants the compliance smoke custom permission.

Smoke seed run order:

- Run `scripts/seedSmokeUsers.apex` first.
- Run `scripts/seedSmokeData.apex` second.

These must run as separate Apex transactions because user and permission-set
assignment work is setup-object DML, while checklist/account seed data is
non-setup DML (`MIXED_DML_OPERATION` if combined).
