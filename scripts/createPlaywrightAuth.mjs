import fs from "fs";
import path from "path";
import { chromium } from "@playwright/test";
import { fileURLToPath } from "url";
import { execFile } from "child_process";
import { promisify, stripVTControlCharacters } from "node:util";

const execFileAsync = promisify(execFile);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return;
  }

  const contents = fs.readFileSync(filePath, "utf8");
  for (const rawLine of contents.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) {
      continue;
    }

    const equalsIndex = line.indexOf("=");
    if (equalsIndex === -1) {
      continue;
    }

    const key = line.slice(0, equalsIndex).trim();
    const value = line.slice(equalsIndex + 1).trim();
    if (key && process.env[key] === undefined) {
      process.env[key] = stripWrappingQuotes(value);
    }
  }
}

function stripWrappingQuotes(value) {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  return value;
}

async function getOrgSession(alias) {
  const { stdout } = await execFileAsync(
    "sf",
    ["org", "display", "--target-org", alias, "--json"],
    {
      cwd: repoRoot,
      env: {
        ...process.env,
        FORCE_COLOR: "0",
        NO_COLOR: "1"
      },
      maxBuffer: 1024 * 1024
    }
  );
  const response = JSON.parse(stripAnsi(stdout));
  const result = response.result || {};

  if (!result.accessToken || !result.instanceUrl) {
    throw new Error(
      `Unable to derive org session for alias "${alias}" from sf org display.`
    );
  }

  return result;
}

function stripAnsi(value) {
  return stripVTControlCharacters(value)
    .replace(/^\uFEFF/, "")
    .trim();
}

async function main() {
  loadEnvFile(path.join(repoRoot, ".env.playwright"));

  const alias = process.env.SF_ORG_ALIAS || "checkr";
  const authFile = path.resolve(
    repoRoot,
    process.env.SF_AUTH_FILE || ".playwright/auth/salesforce.json"
  );
  const retUrl = process.env.SF_LOGIN_RET_URL || "/lightning/page/home";
  const { accessToken, instanceUrl, username } = await getOrgSession(alias);

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto(
    `${instanceUrl}/secur/frontdoor.jsp?sid=${encodeURIComponent(
      accessToken
    )}&retURL=${encodeURIComponent(retUrl)}`,
    { waitUntil: "domcontentloaded" }
  );
  await page.waitForURL(/\/lightning\//);

  fs.mkdirSync(path.dirname(authFile), { recursive: true });
  await context.storageState({ path: authFile });
  await browser.close();

  process.stdout.write(
    `Saved Playwright auth for ${username} (${alias}) to ${authFile}\n`
  );
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exitCode = 1;
});
