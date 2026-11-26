---
title: "Org evidence: apex-local-tests"
---

Outcome: **passed**

Started: 2026-11-25T18:15:47.843Z
Finished: 2026-11-25T18:18:43.809Z
Commit: d67b5e5d111112056aefbdcacf1889021ee22fa6
Package version: source deploy

## Checks

- passed: AER suite completed — 107 tests; exit 0
- passed: Local Apex tests — 113 tests; Passed
- passed: Overall Apex coverage >= 85% — 95%
- passed: Checkr package Apex coverage >= 75% — 95.4%

## Metrics

```json
{
  "aerTestsPassed": 107,
  "aerTestsFailed": 0,
  "aerTestsRan": 107,
  "testsPassed": 113,
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
  "packageCoveragePercent": 95.4,
  "testsRan": 113
}
```
