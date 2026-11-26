---
title: "Org evidence: install-upgrade"
---

Outcome: **passed**

Started: 2026-10-20T20:31:54.591Z
Finished: 2026-10-20T20:39:09.433Z
Commit: 93563c6180264433077fe4ee15ecfe29d26a689e
Package version: 0.1.0.2

## Checks

- passed: starting version installed — 0.1.0.1 04tfj000000duWzAAI
- passed: CKR_User blocked with exact gate error — 
- passed: CKR_User save succeeds after completion — 
- passed: upgraded in place to the new version — 0.1.0.2 04tfj000000duX0AAI
- passed: templates from the first install survive — 1 before, 1 after
- passed: versions from the first install survive — 1 before, 1 after
- passed: instances from the first install survive — 1 before, 1 after
- passed: items from the first install survive — 1 before, 1 after
- passed: auditEvents from the first install survive — 2 before, 2 after
- passed: completed checklist still passes the gate after upgrade — 
- passed: gate still blocks an incomplete record after upgrade — CKREvidence003b286261364e9ead248d1a98b5bdc2 requires completion
- passed: upgrade performed or skipped with a reason — 

## Metrics

```json
{
  "upgradeFrom": "04tfj000000duWzAAI",
  "exactError": "CKREvidence003b286261364e9ead248d1a98b5bdc2 requires completion",
  "upgrade": "performed"
}
```
