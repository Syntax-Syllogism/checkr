---
title: "Org evidence: apex-local-tests"
---

Outcome: **passed**

Started: 2026-10-20T18:56:19.575Z
Finished: 2026-10-20T18:57:50.153Z
Commit: 182f4131f63a1ae76e884c03f6d764d32296021f (dirty)
Package version: source deploy

## Checks

- passed: AER suite completed — 100 tests; exit 0
- passed: Local Apex tests — 106 tests; Passed
- passed: Overall Apex coverage >= 85% — 95%
- passed: Checkr package Apex coverage >= 75% — 95.3%

## Metrics

```json
{
  "aerTestsPassed": 100,
  "aerTestsFailed": 0,
  "aerTestsRan": 100,
  "testsPassed": 106,
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
    },
    {
      "name": "CKR_SmokeSeedIT.dataSeedWithoutSmokeUsersFailsClearly",
      "org": true,
      "aer": "missing"
    },
    {
      "name": "CKR_SmokeSeedIT.userSeedCreatesMissingPersonasAndReassignsPermissions_integrationHappyPath",
      "org": true,
      "aer": "missing"
    },
    {
      "name": "CKR_SmokeSeedIT.userSeedThenDataSeed_integrationHappyPath",
      "org": true,
      "aer": "missing"
    }
  ],
  "coveragePercent": 95,
  "packageCoveragePercent": 95.3,
  "testsRan": 106
}
```
