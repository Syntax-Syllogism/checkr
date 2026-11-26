---
title: "Gate bypass reference integration evidence"
---

Outcome: **passed**

Source commit: 639d604 (clean before the evidence run).
Existing org: `checkr-evidence`; no org created, reset, or deleted.

- Deployment preview exited 0: 116 entries to deploy, zero conflicts, zero retrieves or deletes. No conflict override was needed.
- `sfq apex run test --tests CKR_GateBypassIT --target-org checkr-evidence --result-format json --output-dir /tmp/ckr-round2-apex --wait 20` exited 0.
- 1 test ran, 1 passed, 0 failed or skipped. The test verifies a gated Account update, audit actor/rule/object/time, and custom-permission precedence when both switches are active.

See [redacted Apex results](apex-results.json) and [deployment preview](deploy-preview.json).

The required no-org gate also exited 0: lint, 28 LWC tests, 37 harness tests, and 94 Apex tests passed. The first sandboxed attempt exited 1 because AER could not start; the approved local retry passed.
