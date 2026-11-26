# Playwright E2E Tests

These tests cover browser-level Salesforce behavior for the CheckR record-page
experience. They are intended for a sandbox or scratch org with predictable
sample data and a dedicated test user.

## Install

```bash
npm install
npx playwright install chromium
```

## Authentication

The real `.env.playwright` file is local-only because scratch-org URLs and
record IDs change often. To create or refresh it, run:

```bash
npm run test:e2e:setup
```

That command seeds smoke data, finds the current record IDs, and updates
`.env.playwright` from `.env.playwright.example` when the local file is
missing.

For scratch-org testing, the recommended path is:

```bash
node scripts/createPlaywrightAuth.mjs
```

That script:

- reads `.env.playwright`
- uses `sf org display --target-org <alias> --json`
- opens Salesforce through `frontdoor.jsp`
- saves browser auth state to `.playwright/auth/salesforce.json`

When that auth file already exists, local Playwright runs skip the setup
project and reuse the saved storage state directly. CI still runs the setup
project so fresh environments stay deterministic.

Relevant environment variables in `.env.playwright`:

- `SF_ORG_ALIAS`
  Default: `checkr`
- `SF_AUTH_FILE`
- `SF_LOGIN_RET_URL`
  Optional landing page after frontdoor login

To refresh local auth, delete `.playwright/auth/salesforce.json` and rerun the
suite or regenerate it with the auth script.

## Test Data

The specs assume record IDs for browser navigation. A practical seed option
for sandbox testing is the reference helper at:

- `sfdx-source/reference/classes/CheckrSmokeSeed.cls`

Viewer spec variables:

- `CKR_VIEWER_RECORD_ID`
- `CKR_VIEWER_RECORD_OBJECT_API_NAME`
  Default: `Account`
- `CKR_VIEWER_CHECKLIST_NAME`
  Default: `Account Onboarding`
- `CKR_VIEWER_EXPLANATION_ITEM_LABEL`
  Default: `Confirm executive sponsor`

Create-action spec variables:

- `CKR_CREATE_RECORD_ID`
- `CKR_CREATE_RECORD_OBJECT_API_NAME`
  Default: `Account`
- `CKR_CREATE_ACTION_LABEL`
  Default: `New Checklist`
- `CKR_CREATE_TEMPLATE_LABEL`
  Default: `Account Onboarding (v1)`
- `CKR_CREATE_DUE_DATE`
  Default: `2099-12-31`

The create-action spec should target a record that does not already have a
checklist for the same `template + assignee` combination.

## Run

```bash
npm run test:e2e
```

For headed execution:

```bash
npm run test:e2e:headed
```
