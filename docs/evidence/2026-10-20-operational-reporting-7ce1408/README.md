---
title: "Operational reporting evidence"
---

- Existing authorized org: `checkr-evidence`; no org created, reset or deleted.
- Source base: `7ce14086c936f885a4b86cab8b7079ce40dd5bf5`, with implementation changes present (see summary).
- Reporting metadata, Age Band field and CKR_Admin deployment: **12/12 passed**,
  deployment ID `0AfRK00000uvg8j0AA`.
- [Read-only validation script](validate-reports.apex) queried exactly three
  reports and executed each with `Reports.ReportManager.runReport(id, false)`;
  `sf apex run --file <script> --target-org checkr-evidence --json` exited 0,
  compiled and succeeded. [Summary](summary.json) retains only report names and
  fact-map sizes; no rows, credentials, usernames or org URLs are saved.
- Reports: Open checklists by template and age; Recent checklist audit activity;
  Gate bypasses by actor and object.

The run used the authenticated admin and existing org data, with no reporting
fixtures. Successful execution does not establish populated grouping counts,
Age Band boundary behavior on records, or restricted-user visibility. Interactive
dashboard rendering was skipped because this run is unattended. The dynamic
LoggedInUser dashboard deployed successfully in this org.

The no-org gate exited 0: lint, 28 LWC tests, 41 org-harness tests,
6 reporting metadata checks and 100 Apex tests. Local AER v1.4.32 differs from
the CI pin v1.5.4; the gate emitted its version warning.

Initial deployment attempts caught the date-interval enum and required dashboard
section. Both were corrected before the successful deployment; failed deployment
attempts are not passing evidence. The first read-only Apex validation script
had a local variable shadowing the Reports namespace; the saved script corrects
that and is the one that passed.

## Re-check at committed SHA 2e466fb

After the XML in this tree was formatted and committed as `2e466fb`, the same
12 components were deployed again to `checkr-evidence` (deploy
`0AfRK00000uvga90AA`). Running `validate-reports.apex` again executed all three
reports: `CKR_Gate_Bypasses`, `CKR_Open_Checklists` and
`CKR_Recent_Audit_Activity`, each with a single fact-map entry. The limits
above still apply.
