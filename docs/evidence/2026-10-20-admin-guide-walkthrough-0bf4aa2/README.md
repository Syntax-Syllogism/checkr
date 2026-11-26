---
title: "Admin guide walkthrough: beta 0.1.0-1"
---

- **Date:** 2026-10-20
- **Org:** scratch org with `checkr` 0.1.0.1 (`04tfj000000duWzAAI`) installed
  for Admins Only, the Account reference shim deployed, and the running System
  Administrator holding `CKR_Admin` and `CKR_User`
- **Result:** 49 of 49 steps passed ([walkthrough.json](walkthrough.json))
- **Script:** [walkthrough.mjs](walkthrough.mjs)
  (`node walkthrough.mjs <alias> <out-dir>`)

The walkthrough follows admin guide chapters 2 to 11 and the
[gate-blocking-saves runbook](../../runbooks/gate-blocking-saves.md). It uses
the field names from the chapter tables and the Apex entry points the UI calls:
`CKR_TemplateVersionPublishController.publishVersion` (Publish Version),
`CKR_ChecklistCreateActionController` (New Checklist) and
`CKR_ChecklistViewerController.updateChecklistItem` (the viewer). It is an API
walkthrough. The UI screens were not clicked through for this run; the
screenshots in the guide come from `npm run docs:screenshots`.

## What it covers

- **Chapter 2:** package, CheckR app and tabs, five permission sets,
  `CKR_Admin` without bypass, components, quick actions and the Account page.
- **Chapter 3:** the shipped Account supported-object record and the shim, and a
  record with no checklist blocked with the rule's message.
- **Chapters 4 and 5:** template, Draft version, required, picklist-explanation
  and optional items, and `AnyFieldValueChange` and `SpecificFieldValueChange`
  rules. Inserts are not gated (D3); a Draft does not gate.
- **Chapter 6:** publish, frozen items and rules, direct Status changes and
  empty or repeat publishes rejected, v2 cutover and the D2 table row by row.
- **Chapter 7:** New Checklist, one checklist per record and template, item
  completion with and without a required explanation, the complete save, and
  audit events.
- **Chapter 8:** both bypass options with their recorded source, and removal
  restoring the gate.
- **Chapters 9 and 11, runbook:** append-only audit history, blocked template
  delete, and the runbook's rule lookup and triage queries.

## Findings

The first two runs failed. Both causes were in the docs, not the package:

1. **The install grants the System Administrator profile bypass and audit
   maintenance.** Installing for Admins Only gave that profile the
   `CKR_BypassGate` and `CKR_Audit_Maintenance` custom permissions, so the
   admin's blocked saves went through as bypasses and the admin could edit
   audit events. The guide said nobody holds them by default. The grants can
   be removed (deleting the profile's `SetupEntityAccess` rows worked), and the
   docs now make this a post-install step. The passing run starts with a check
   that no profile holds either permission.
2. **An inactive template still gates.** The gate reads rules by version
   status and ignores the template's Active box, but chapter 4 described
   unchecking it as retiring the template. The docs now say Active only hides
   the template from New Checklist, and chapter 6 describes retiring a
   template's gates by publishing a version with no rules. The script retires
   earlier runs' templates that way.

Whether Active should also stop gating is a product question, left open.
