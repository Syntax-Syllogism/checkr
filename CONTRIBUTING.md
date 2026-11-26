# Contributing to CheckR

Thanks for helping out. CheckR is an open-source checklist framework for
Salesforce, and we welcome bug reports, feature ideas, and pull requests.

## Ways to contribute

1. **Report a bug.** Open an issue with a clear description, steps to
   reproduce it, and the CheckR version or commit.
2. **Suggest a feature.** Open an issue to discuss it before you start
   building.
3. **Send a pull request.**
   - Fork the repository and create a topic branch.
   - Write clear code and tests. Apex classes with meaningful logic need a
     `*Test.cls` that covers positive, negative, and bulk paths.
   - Run `npm test` (the full no-org suite) and `node scripts/gate.mjs` (the
     suite, Code Analyzer when installed, and the AER Apex tests). Also run
     `npm run analyze`, which must report zero findings.
   - Write commit messages in [Conventional Commits](https://www.conventionalcommits.org/)
     form, for example `fix(gate): handle null parent ids`. The `commit-msg`
     hook checks them.
   - Open a pull request that describes the change and how you verified it.

Everyone taking part is expected to follow the
[Code of Conduct](CODE_OF_CONDUCT.md). Security issues go through [SECURITY.md](SECURITY.md), not public issues.

## Development setup

Local development needs Node 22+, [afmt](https://github.com/xixiaofinland/afmt)
1.0.0, and the [AER](https://aertest.com) binary pinned in
`.github/workflows/ci.yml`. Run `npm ci` once to install dependencies and the
commit hooks.

[Testing, gate, and CI](docs/testing.md) describes each command. The
[architecture guide](docs/architecture.md) covers the Apex layers, the
`CKR_AppFactory` seams, the system-mode rules, and the test pattern; read it
before a larger change.
