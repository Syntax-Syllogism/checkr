# Org evidence: apex-local-tests

Outcome: **failed**

Started: 2026-10-20T15:08:57.167Z
Finished: 2026-10-20T15:10:48.669Z
Commit: b0091a52a5deaf6eee8fa7df8412f7d229f657ad (dirty)
Package version: source deploy

## Checks

- passed: AER suite completed — 100 tests; exit 0
- passed: Local Apex tests — 103 tests; Passed
- failed: Overall Apex coverage >= 75% — 62%

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
  "coveragePercent": 62,
  "testsRan": 103
}
```
