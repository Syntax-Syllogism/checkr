const { expect } = require("@playwright/test");
const { loadEnvFile } = require("./loadEnv");
const { getOrgSession } = require("./scratchOrg");

loadEnvFile(".env.playwright");

let cachedOrgBaseUrl;

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var ${name}.`);
  }
  return value;
}

function createSafeTestLabel(prefix) {
  return `${prefix} ${new Date().toISOString().replace(/[^\dTZ]/g, "")}`;
}

async function openRecordPage(page, objectApiName, recordId) {
  const appName = process.env.CKR_BROWSER_APP_NAME || "CheckR";
  const orgBaseUrl = await getOrgBaseUrl();
  const baseUrl = resolveBaseUrl(orgBaseUrl);
  const recordUrl = `${baseUrl}/lightning/r/${objectApiName}/${recordId}/view`;
  const homeUrl = `${baseUrl}/lightning/page/home`;

  if (!(await isCheckrAppContext(page, appName))) {
    await page.goto(homeUrl, { waitUntil: "domcontentloaded" });
    await waitForLightningShell(page);
    await switchToApp(page, appName);
  }

  await page.goto(recordUrl, { waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(
    new RegExp(`/lightning/r/${objectApiName}/${recordId}/view`)
  );
  await waitForRecordPageShell(page, objectApiName);
}

async function openRecordPageFromApp(page, objectApiName, recordId) {
  const orgBaseUrl = await getOrgBaseUrl();
  const baseUrl = resolveBaseUrl(orgBaseUrl);
  const recordUrl = `${baseUrl}/lightning/r/${objectApiName}/${recordId}/view`;

  await page.goto(recordUrl, { waitUntil: "domcontentloaded" });
  await expect(page).toHaveURL(
    new RegExp(`/lightning/r/${objectApiName}/${recordId}/view`)
  );
  await waitForRecordPageShell(page, objectApiName);
}

async function getOrgBaseUrl() {
  if (cachedOrgBaseUrl) {
    return cachedOrgBaseUrl;
  }

  const alias = process.env.SF_ORG_ALIAS || "checkr";
  const { instanceUrl } = await getOrgSession(alias);
  cachedOrgBaseUrl = instanceUrl;
  return cachedOrgBaseUrl;
}

function resolveBaseUrl(orgBaseUrl) {
  const configuredBaseUrl = process.env.SF_BASE_URL;
  if (!configuredBaseUrl) {
    return orgBaseUrl;
  }

  try {
    const configuredHost = new URL(configuredBaseUrl).hostname;
    const orgHost = new URL(orgBaseUrl).hostname;
    return configuredHost === orgHost ? configuredBaseUrl : orgBaseUrl;
  } catch (_error) {
    return orgBaseUrl;
  }
}

async function waitForRecordPageShell(page, objectApiName) {
  await expect(
    page
      .getByRole("heading", {
        level: 1,
        name: new RegExp(objectApiName, "i")
      })
      .first()
  ).toBeVisible({ timeout: 45_000 });
}

async function waitForLightningShell(page) {
  await expect(page).toHaveURL(/\/lightning\//);
  await expect(
    page.getByRole("button", { name: "App Launcher" }).first()
  ).toBeVisible({ timeout: 45_000 });
}

async function isCheckrAppContext(page, appName) {
  const appHeading = page.getByRole("heading", {
    level: 1,
    name: new RegExp(`^${escapeRegExp(appName)}$`, "i")
  });
  return isVisible(appHeading.first());
}

async function switchToApp(page, appName) {
  const appHeading = page.getByRole("heading", {
    level: 1,
    name: new RegExp(`^${escapeRegExp(appName)}$`, "i")
  });
  if (await isVisible(appHeading.first())) {
    return;
  }

  if (await openAppByUrl(page, appHeading)) {
    return;
  }

  await openAppFromLauncher(page, appName, appHeading);
}

async function openAppByUrl(page, appHeading) {
  const currentUrl = new URL(page.url());
  const appDeveloperName =
    process.env.CKR_BROWSER_APP_DEVELOPER_NAME || "CheckR";
  const appTargets = unique([
    appDeveloperName,
    appDeveloperName.startsWith("c__")
      ? appDeveloperName
      : `c__${appDeveloperName}`
  ]);

  for (const appTarget of appTargets) {
    await page.goto(
      `${currentUrl.origin}/lightning/app/${encodeURIComponent(appTarget)}`,
      { waitUntil: "domcontentloaded" }
    );

    if (await isVisible(appHeading.first(), 15_000)) {
      return true;
    }
  }

  return false;
}

async function openAppFromLauncher(page, appName, appHeading) {
  await page.getByRole("button", { name: "App Launcher" }).first().click();

  const searchBox = page
    .getByPlaceholder(/Search apps and items/i)
    .or(page.getByRole("textbox", { name: /Search apps and items/i }))
    .first();
  await expect(searchBox).toBeVisible({ timeout: 30_000 });
  await searchBox.fill(appName);

  if (await clickLauncherAppOption(page, appName, 10_000)) {
    await expect(appHeading.first()).toBeVisible({ timeout: 45_000 });
    return;
  }

  const viewAll = page.getByRole("link", { name: /^View All$/i }).first();
  if (await isVisible(viewAll, 5_000)) {
    await viewAll.click();
    const allAppsSearchBox = page
      .getByPlaceholder(/Search apps or items/i)
      .or(page.getByRole("textbox", { name: /Search apps or items/i }))
      .first();
    await expect(allAppsSearchBox).toBeVisible({ timeout: 30_000 });
    await allAppsSearchBox.fill(appName);
  }

  if (await clickLauncherAppOption(page, appName, 30_000)) {
    await expect(appHeading.first()).toBeVisible({ timeout: 45_000 });
    return;
  }

  throw new Error(`Unable to switch to the ${appName} Salesforce app.`);
}

async function clickLauncherAppOption(page, appName, timeout) {
  const appNamePattern = new RegExp(`^${escapeRegExp(appName)}$`, "i");
  const appOption = page
    .getByRole("link", { name: appNamePattern })
    .or(page.getByRole("option", { name: appNamePattern }))
    .or(page.getByText(appNamePattern))
    .first();

  if (!(await isVisible(appOption, timeout))) {
    return false;
  }

  await appOption.click();
  return true;
}

async function isVisible(locator, timeout = 1_000) {
  try {
    await expect(locator).toBeVisible({ timeout });
    return true;
  } catch (_error) {
    return false;
  }
}

function unique(values) {
  return Array.from(new Set(values.filter(Boolean)));
}

async function findChecklistViewer(page, checklistName) {
  const viewer = page
    .locator("ckr-checklist-viewer")
    .or(
      page.locator("article").filter({
        has: page.getByRole("heading", { name: "CheckR Checklist Viewer" })
      })
    )
    .first();
  await expect(viewer).toBeVisible({ timeout: 60_000 });

  const checklistButton = viewer.getByRole("button", {
    name: new RegExp(`${escapeRegExp(checklistName)} \\(`)
  });
  await expect(checklistButton.first()).toBeVisible({ timeout: 30_000 });

  return viewer;
}

async function maybeOpenAccordionSection(page, checklistName) {
  const button = page.getByRole("button", {
    name: new RegExp(`${escapeRegExp(checklistName)} \\(`)
  });
  if (await button.count()) {
    const expanded = await button.first().getAttribute("aria-expanded");
    if (expanded !== "true") {
      await button.first().click();
    }
  }
}

async function maybeCloseToast(page) {
  const closeButton = page.getByRole("button", { name: /dismiss|close/i });
  if (await closeButton.count()) {
    await closeButton.first().click();
  }
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

module.exports = {
  createSafeTestLabel,
  findChecklistViewer,
  maybeCloseToast,
  maybeOpenAccordionSection,
  openRecordPageFromApp,
  openRecordPage,
  requireEnv
};
