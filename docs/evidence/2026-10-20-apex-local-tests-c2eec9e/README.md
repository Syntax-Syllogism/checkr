---
title: "Org evidence: apex-local-tests"
---

Outcome: **failed**

Started: 2026-10-20T00:46:01.676Z
Finished: 2026-10-20T00:47:27.104Z
Commit: c2eec9e2d15da2438bd506d430776f3aac9b9719
Package version: source deploy

## Checks

- passed: AER suite completed — 73 tests; exit 0
- failed: Local Apex tests — 73 tests; Failed
- failed: Overall Apex coverage >= 75% — 56%

## Metrics

```json
{
  "aerTestsPassed": 73,
  "aerTestsFailed": 0,
  "aerTestsRan": 73,
  "testsPassed": 70,
  "testsFailed": 3,
  "aerDifferences": [
    {
      "name": "CKR_UserModeIT.ckrUser_addsEditsAndRemovesAdHocItem_integrationHappyPath",
      "org": false,
      "aer": true,
      "orgMessage": "System.AuraHandledException: Script-thrown exception"
    },
    {
      "name": "CKR_UserModeIT.ckrUser_completesItem_integrationHappyPath",
      "org": false,
      "aer": true,
      "orgMessage": "System.AuraHandledException: Script-thrown exception"
    },
    {
      "name": "CKR_UserModeIT.ckrUser_completingItem_rollsUpInstanceStatus_integrationHappyPath",
      "org": false,
      "aer": true,
      "orgMessage": "System.AuraHandledException: Script-thrown exception"
    }
  ],
  "coveragePercent": 56,
  "testsRan": 73
}
```
