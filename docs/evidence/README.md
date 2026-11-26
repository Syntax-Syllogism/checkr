---
title: "Org evidence"
---

This explicit harness replaces the former scratch-org integration workflow.
It does not run in CI. The latest run of each scenario is linked below.

```sh
npm run org:evidence -- --scenario apex-local-tests --org <alias>
npm run org:evidence -- --scenario gate-block-pass,insert-gating,bulk-200 --org <alias>
npm run test:org-harness
```

Every source run deploys `sfdx-source/checkr` and `sfdx-source/reference`, including
the Account trigger shim. It assigns `CKR_Admin` to the caller if missing. Use a
dedicated development org with no conflicting Account rules or automation.

| Scenario           | Coverage                                                            | Latest run                                               |
| ------------------ | ------------------------------------------------------------------- | -------------------------------------------------------- |
| `apex-local-tests` | Real Apex tests, coverage, same-source AER comparison               | [latest](2026-11-25-apex-local-tests-d67b5e5/README.md)  |
| `gate-block-pass`  | CKR_User blocked, then allowed after checklist completion           | [latest](2026-10-20-gate-block-pass-b3c31cf/README.md)   |
| `insert-gating`    | Before-insert baseline: inserts are not gated                       | [latest](2026-10-20-insert-gating-fd6de64-2/README.md)   |
| `bulk-200`         | 200 updates, three rules, 100 blocked, SOQL and CPU                 | [latest](2026-10-20-bulk-200-b3c31cf/README.md)          |
| `install-smoke`    | Clean package install, packaged metadata, shim, gate block/pass     | [latest](2026-11-26-install-smoke-ff31b1b/README.md) |
| `install-upgrade`  | Beta-to-beta upgrade keeps checklist data; gate still enforces      | [latest](2026-11-26-install-upgrade-3ca4df6/README.md) |
| `version-cutover`  | Version lifecycle cutover, completed v1, blocked v2, immutable rule | [latest](2026-10-20-version-cutover-fd6de64-2/README.md) |
| `bypass`           | Permission + setting saves, source precedence, audit integrity      | [latest](2026-10-20-bypass-ef9f45b/README.md)            |
| `audit-integrity`  | Append-only events, instance cascade guard, temporary maintenance   | [latest](2026-10-20-audit-integrity-4a7edfa/README.md)   |

## Findings

- **`apex-local-tests`:** the latest run passes all 113 org Apex tests with
  95% org-wide and 95.4% packaged Apex coverage. The AER comparison in the
  scenario runs 107 tests; the local gate runs every test in `checkr` and
  `reference`. AER does not enforce record sharing, so sharing-dependent
  `*IT` tests must pass in a Private-OWD org through this harness.
- **`bulk-200`:** 100 allowed and 100 blocked as expected, with 2 SOQL queries
  and 78 ms CPU for the gate across 200 records and 3 rules.
- **`insert-gating`:** an Account insert whose values match an active rule is
  **not blocked** in a real org. Inserts are not gated by design.
- **`bypass`:** permission and setting saves, source precedence, and audit
  integrity all pass; the
  [reference integration test](2026-10-20-gate-bypass-it-639d604/README.md)
  passes too. Earlier failed attempts remain as history.
- **Beta 0.1.0-1:** [install-smoke](2026-10-20-install-smoke-0bf4aa2/README.md)
  passes in a fresh scratch org, and an
  [admin guide walkthrough](2026-10-20-admin-guide-walkthrough-0bf4aa2/README.md)
  passes 49 of 49 steps against the installed beta. The walkthrough found that
  installing for Admins Only grants the System Administrator profile gate
  bypass and audit maintenance, and that an inactive template still gates.
  Both are documented in the [installation guide](../installation.md).
- **Beta 0.1.0-2:** [install-upgrade](2026-10-20-install-upgrade-93563c6/README.md)
  upgrades 0.1.0-1 in place in the same org. Checklist data survives, and the
  gate still blocks and passes. The upgrade did not re-grant the System
  Administrator profile the bypass and audit maintenance permissions removed
  after the first install. That is one observation, so the upgrade steps still
  say to re-run the check.

See [scenario details](scenarios.md) for prerequisites, assertions, and limits.

Without an org choice the harness fails with `pass --org <alias> or
--create-scratch`. Only pass `--create-scratch` when you intend to create a scratch org;
it creates from `config/project-scratch-def.json` using the authenticated Dev
Hub (`DEVHUB_ALIAS`, default `devHub`). It deletes only the org it created.
`--org` and `--create-scratch` cannot be combined. Existing orgs are never reset
or deleted.

`--keep` retains scenario fixtures, users and any created scratch org. Otherwise,
fixtures are deleted, newly assigned worker permission sets removed, and newly
created users deactivated (Salesforce cannot delete users). Source deployments
and the caller's admin permission set remain. Failure still triggers cleanup.

Runs write `docs/evidence/<date>-<scenario>-<short-commit>/summary.json` and `README.md`,
plus redacted CLI artifacts, metrics and errors. Repeated runs get numeric
suffixes; previous evidence is never overwritten. This catalog automatically
links the most recent attempt, including failures. Inspect the outcome before
citing it. Summaries record commit, dirty state, package version (null for
source), org edition/type, checks and metrics. Credentials and usernames are
redacted; review artifacts before committing. Logs are bounded; summaries and
the 200-row bulk results remain structured JSON.

`--package <04t>` and `--upgrade-from <04t>` are for the `install-smoke` and
`install-upgrade` scenarios, which install the package instead of deploying
source. They run alone, need a fresh scratch org (they refuse `checkr-evidence`
and any org in `CKR_EVIDENCE_ORG`), and deploy only the reference Account
trigger shim from source. Source scenarios reject the package flags.

## Operational reporting

[Reporting metadata and execution validation](2026-10-20-operational-reporting-7ce1408/README.md): 12/12 components deployed and all three starter reports executed in `checkr-evidence`; no reporting fixtures or interactive dashboard inspection.
