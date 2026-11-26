---
title: "Org evidence: apex-local-tests"
---

Outcome: **failed**

Started: 2026-10-20T14:43:08.657Z
Finished: 2026-10-20T14:44:53.474Z
Commit: 591a832fa21e3e9adb8424e3d2129abefe4f4b2f (dirty)
Package version: source deploy

## Checks

- passed: AER suite completed — 100 tests; exit 0
- failed: Local Apex tests — 103 tests; Failed
- failed: Overall Apex coverage >= 75% — 62%

## Metrics

```json
{
  "aerTestsPassed": 100,
  "aerTestsFailed": 0,
  "aerTestsRan": 100,
  "testsPassed": 102,
  "testsFailed": 1,
  "aerDifferences": [
    {
      "name": "CKR_AuditMaintenanceIT.assignedMaintenanceAllowsChanges_integrationHappyPath",
      "org": false,
      "aer": "missing",
      "orgMessage": "System.DmlException: Operation failed due to fields being inaccessible on Sobject CKR_ChecklistAuditEvent__c, check errors on Exception or Result!"
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
