const path = require("path");
const fs = require("fs");
const { defineConfig, devices } = require("@playwright/test");
const { loadEnvFile } = require("./tests/playwright/support/loadEnv");

loadEnvFile(path.join(__dirname, ".env.playwright"));

const configuredAuthFile =
  process.env.SF_AUTH_FILE ||
  path.join(__dirname, ".playwright", "auth", "salesforce.json");
const authFile = path.isAbsolute(configuredAuthFile)
  ? configuredAuthFile
  : path.join(__dirname, configuredAuthFile);
const useSetupProject = Boolean(process.env.CI) || !fs.existsSync(authFile);

module.exports = defineConfig({
  testDir: path.join(__dirname, "tests", "playwright"),
  timeout: 180_000,
  expect: {
    timeout: 15_000
  },
  fullyParallel: false,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  reporter: [
    ["list"],
    ["html", { outputFolder: "playwright-report", open: "never" }]
  ],
  use: {
    baseURL: process.env.SF_BASE_URL,
    headless: process.env.PW_HEADLESS !== "false",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    storageState: authFile
  },
  projects: [
    ...(useSetupProject
      ? [
          {
            name: "setup",
            testMatch: /auth\.setup\.js/,
            use: {
              storageState: undefined
            }
          }
        ]
      : []),
    {
      name: "chromium",
      use: {
        ...devices["Desktop Chrome"]
      },
      ...(useSetupProject ? { dependencies: ["setup"] } : {})
    }
  ]
});
