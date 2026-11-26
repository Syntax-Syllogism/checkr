# Template retention review regression

Outcome: **passed** in the existing authorized `checkr-evidence` org.
Source base: `d557d7c`, with the round 3 test changes uncommitted at execution.
No org was created, reset, or deleted.

- Source deployment through `sfq project deploy start` exited 0: 215/215
  components, zero component errors, no conflict override.
- `sfq apex run test --tests CKR_AuditRecordGuardTest --tests CKR_AuditMaintenanceIT --target-org checkr-evidence --result-format json --output-dir /tmp/ckr-round3-salesforce --wait 20`
  exited 0: seven passed, zero failed or skipped.
- `referencedGateRuleDeletion_integrationHappyPath` directly asserts the concrete
  system-mode selector returns the referenced template and version IDs. Deleting
  either parent must return `FIELD_CUSTOM_VALIDATION_EXCEPTION` and the exact
  retention message, rather than an unhandled query/field exception. It also
  verifies the bypass event and rule link survive each blocked deletion.
- This validates the existing grouped relationship query: Salesforce returns an
  `AggregateResult` exposing `CKR_ChecklistTemplate__c` by its leaf field name.
  The production selector remains unchanged. A separate rollback-only anonymous
  probe also confirmed this result shape (user mode, as required for anonymous
  execution); the deployed regression above exercises system mode.
- Required `node scripts/gate.mjs` exited 0: lint, 28 LWC tests, 40 harness
  tests, and 100 Apex tests. Targeted local guard tests: 6/6 passed. Local AER
  v1.4.32 differs from CI v1.5.4; the existing warning remains.

See [redacted Salesforce results](apex-results.json). Only test names, outcomes,
and counts are retained; org/user IDs and deployment IDs are omitted.
