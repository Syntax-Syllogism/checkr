---
title: "Org evidence: install-upgrade"
---

Outcome: **passed**

Started: 2026-11-26T09:32:11.742Z
Finished: 2026-11-26T09:39:43.726Z
Commit: 3ca4df69542f16467f533c221dfb270510cef677
Package version: 0.1.3.1

## Checks

- passed: starting version installed — 0.1.2.1 04tfj000000ntszAAA
- passed: CKR_User blocked with exact gate error — 
- passed: CKR_User save succeeds after completion — 
- passed: upgraded in place to the new version — 0.1.3.1 04tfj000000nuPFAAY
- passed: templates from the first install survive — 1 before, 1 after
- passed: versions from the first install survive — 1 before, 1 after
- passed: instances from the first install survive — 1 before, 1 after
- passed: items from the first install survive — 1 before, 1 after
- passed: auditEvents from the first install survive — 2 before, 2 after
- passed: completed checklist still passes the gate after upgrade — 
- passed: gate still blocks an incomplete record after upgrade — CKREvidenced831ebbfe8a3487b99e7368c7836c6ad requires completion
- passed: upgrade performed or skipped with a reason — 

## Metrics

```json
{
  "upgradeFrom": "04tfj000000ntszAAA",
  "exactError": "CKREvidenced831ebbfe8a3487b99e7368c7836c6ad requires completion",
  "upgrade": "performed"
}
```
