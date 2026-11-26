---
title: "CheckR admin guide"
---

This guide is for Salesforce administrators who set up and run CheckR: enabling
an object, authoring checklist templates and gate rules, publishing versions,
granting access, handling data loads with bypass, and reviewing history. It
assumes you know Setup, permission sets, Lightning record pages, and custom
metadata, and does not explain those.

CheckR attaches versioned checklists to business records and can block a save
until the checklist is complete. You describe the checklist once, as a
**template version**; users work a snapshot of it on each record.

## What you will be able to do

- Deploy CheckR, assign its permission sets, and enable an object.
- Author a template, add items and gate rules, and publish v1 and later v2.
- Know what happens to existing records when a new version publishes.
- Let a data load or integration through a gate, with an audit trail.
- Review audit history and the operational reports.
- Investigate and fix a blocked save.

## Chapters

1. [Overview](01-overview.md): concepts and how they fit together. Read this
   first; the rest of the guide uses these terms.
2. [Install and permission sets](02-install-and-permissions.md): deploying
   CheckR and who gets which permission set.
3. [Enabling an object](03-enabling-an-object.md): the supported-object record
   and the trigger shim.
4. [Authoring a template](04-authoring-a-template.md): templates, versions,
   items, and completion access mode.
5. [Gate rules](05-gate-rules.md): what a rule watches, examples, and what is
   not gated.
6. [Publishing and new versions](06-publishing-and-new-versions.md): the
   Publish Version action and its effect on existing records.
7. [Working a checklist](07-working-a-checklist.md): the end user's view, in
   brief.
8. [Bypass for data loads and integrations](08-bypass.md): letting saves
   through a gate, with an audit trail.
9. [Audit history and retention](09-audit-history.md): what is recorded and how
   long to keep it.
10. [Reports](10-reports.md): the CheckR Operations reports and dashboard.
11. [Troubleshooting](11-troubleshooting.md): symptom, cause, fix.

When users cannot save records because of a gate, go straight to the
[gate-blocking-saves runbook](../runbooks/gate-blocking-saves.md).

## Screenshots

Screenshots come from a source-deployed scratch org with the docs seed data in
`scripts/docs/seedDocsData.apex`, captured by `npm run docs:screenshots`. Names
and hosts in them are placeholders.
