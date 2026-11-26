---
title: "Releases"
---

How CheckR versions reach you. Installing is covered in
[installation](installation.md); building a package version is covered in
[packaging](packaging.md).

## Package versions

CheckR ships as the unlocked package `checkr`. Each released version has a
`04t` install link and an entry in the [changelog](../CHANGELOG.md), which is
the list of supported versions. Check the changelog for the latest version
before you install or upgrade.

## Source repository

The public repository is a filtered snapshot of the maintainers' development
repository. It holds the Salesforce source, the reference metadata, the
documentation, the tests, and the CI configuration. Maintainer-only tooling and
working notes are not part of the snapshot.

Each tagged snapshot corresponds to a changelog entry. Pull requests are
reviewed and merged in the maintainers' repository, then appear in the next
snapshot. See [CONTRIBUTING](../CONTRIBUTING.md) for how to propose a change.

## Verification before a release

A version is not shared until it has:

- a passing no-org suite and Apex tests (see [testing](testing.md));
- a passing `install-smoke` run in a fresh scratch org and, when an earlier
  promoted version exists, a passing `install-upgrade` run from it (see
  [packaging](packaging.md#evidence-before-sharing-a-version));
- a changelog entry with the package version Id.
