---
title: "Org evidence: apex-local-tests"
---

Outcome: **failed**

Started: 2026-10-20T15:21:08.824Z
Finished: 2026-10-20T15:23:04.952Z
Commit: c1b96859dea676c1ed485f699a98389016ebbf15 (dirty)
Package version: source deploy

## Checks

- passed: AER suite completed — 100 tests; exit 0
- passed: Local Apex tests — 103 tests; Passed
- failed: Overall Apex coverage >= 75% — 63%

## Metrics

```json
{
  "aerTestsPassed": 100,
  "aerTestsFailed": 0,
  "aerTestsRan": 100,
  "testsPassed": 103,
  "testsFailed": 0,
  "aerDifferences": [
    {
      "name": "CKR_AuditMaintenanceIT.assignedMaintenanceAllowsChanges_integrationHappyPath",
      "org": true,
      "aer": "missing"
    },
    {
      "name": "CKR_GateBypassIT.assignedPermissionUpdatesGatedAccount_integrationHappyPath",
      "org": true,
      "aer": "missing"
    },
    {
      "name": "CKR_InsertGatingIT.insertingMatchingRecordIsNotGatedByDesign",
      "org": true,
      "aer": "missing"
    }
  ],
  "coveragePercent": 63,
  "testsRan": 103
}
```
