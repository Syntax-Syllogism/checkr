# CheckR documentation

CheckR attaches versioned checklists to Salesforce records and gates record
saves on them. Start with the [project README](../README.md) for setup, then use
the guides below for the details of one area.

## Admins and operators

- [Installation](installation.md): prerequisites, package install, permission sets, enabling an object with a trigger shim and its test, upgrade, uninstall order, and troubleshooting.
- [Admin guide](admin-guide/README.md): chaptered, with screenshots: install, enabling an object, authoring templates, gate rules, publishing, working a checklist, bypass, audit history, reports, and troubleshooting.
- [Template version publishing](template-version-publishing.md): admin steps for publishing a Draft version and what becomes immutable.
- [Gate bypass operations](gate-bypass.md): temporary bypass, hierarchy settings, and audit review.
- [Records and retention](records-and-retention.md): append-only audit history, deletion controls, and manual archiving.
- [Operational reporting](admin-guide/10-reports.md#operational-reporting): open checklists by template and age, recent audit activity, gate bypasses, and the CheckR Operations dashboard.
- [Runbooks](runbooks/README.md): incident procedures, starting with [users can't save records because of a gate](runbooks/gate-blocking-saves.md).

## Reference

- [Architecture](architecture.md): Apex layers, data-access seams, the system-mode sites table (checked by `npm run test:system-mode`), template version lifecycle, gate evaluation, and test tiers.
- [Security](security.md): permission sets and the generated object access table, org-wide defaults and their rationale, system-mode sites, bypass, audit, and vulnerability reporting.
- [Object model](object-model.md): every `CKR_` object, field, sharing model, and relationship, checked against metadata by `npm run test:object-model`.
- [Platform constraints](platform-constraints.md): gate cost, one instance per record and template, ungated inserts, trigger shims, string value matching, and AER limits.

## Development and release

- [Testing, gate, and CI](testing.md): the no-org suite, Code Analyzer (`npm run analyze`), `scripts/gate.mjs`, the CI jobs, commit hooks, toolchain pins, and AER known issues.
- [Org evidence](evidence/README.md): explicit real-org validation and latest runs, with [scenario](evidence/scenarios.md) prerequisites and assertions.
- [Packaging](packaging.md): the unlocked `checkr` package, why it has no namespace, version numbering, cutting a beta with `npm run release:beta`, and the evidence a version needs.
- [Release](release.md): package versions, the public snapshot, and pre-release verification.
- [Contributing](../CONTRIBUTING.md), [code of conduct](../CODE_OF_CONDUCT.md), [security policy](../SECURITY.md), [changelog](../CHANGELOG.md), and [license](../LICENSE).
