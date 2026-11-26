# Security Policy

## Supported Versions

CheckR is maintained by Syntax & Syllogism and is in pre-1.0 development.
Only the latest beta package version receives security fixes; a fix ships as a
new beta, and you upgrade to it (see
[installation](docs/installation.md#upgrade)).

| Version                      | Supported |
| ---------------------------- | --------- |
| Latest beta in the CHANGELOG | ✅        |
| Older `0.x` betas            | ❌        |

The [CHANGELOG](CHANGELOG.md) lists every beta with its package version Id.

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Email a description to the Syntax & Syllogism maintainer at
**<j.p.richter@gmail.com>** with:

- a clear description of the issue,
- reproduction steps or a proof of concept,
- the affected version (package version Id `04t...`, commit SHA, or release
  tag), and
- the impact you believe the issue has.

## Public Disclosure

A vulnerability is disclosed in the release notes of the version that fixes
it.

Reporters are credited in the release notes unless they request otherwise.

## Scope

In scope:

- The CheckR source in this repository.
- The `checkr` unlocked package versions listed in the CHANGELOG.

Out of scope:

- Vulnerabilities in third-party dependencies or upstream platforms — please
  report those to their respective maintainers.
- Issues that require an attacker to already hold Salesforce administrator
  privileges (for example, Customize Application or Modify All Data) in the
  org where CheckR is installed.
- Gate bypass or audit maintenance used by a user who was assigned
  `CKR_GateBypass`, `CKR_AuditMaintenance`, or the `CKR_Settings__c` bypass
  switch; these are documented privileges (see `docs/security.md`).
- The System Administrator profile holding `CKR_BypassGate` and
  `CKR_Audit_Maintenance` after an Admins Only install or upgrade. This is a
  known, documented install behaviour; remove the grant as described in
  [installation](docs/installation.md#remove-the-admin-profiles-bypass-and-audit-maintenance).

Please do not include production credentials or unredacted Salesforce data in
a report. Attach a minimal reproduction or sanitized sample instead.
