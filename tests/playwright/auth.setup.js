const fs = require("fs");
const path = require("path");
const { test, expect } = require("@playwright/test");
const { getOrgSession } = require("./support/scratchOrg");

const authFile =
  process.env.SF_AUTH_FILE ||
  path.join(__dirname, "..", "..", ".playwright", "auth", "salesforce.json");

test("capture Salesforce storage state", async ({ page }) => {
  const alias = process.env.SF_ORG_ALIAS || "checkr";
  const retUrl = process.env.SF_LOGIN_RET_URL || "/lightning/page/home";
  const { accessToken, instanceUrl } = await getOrgSession(alias);

  await page.goto(
    `${instanceUrl}/secur/frontdoor.jsp?sid=${encodeURIComponent(
      accessToken
    )}&retURL=${encodeURIComponent(retUrl)}`,
    { waitUntil: "domcontentloaded" }
  );

  await expect(page).toHaveURL(/\/lightning\//);

  fs.mkdirSync(path.dirname(authFile), { recursive: true });
  await page.context().storageState({ path: authFile });
});
