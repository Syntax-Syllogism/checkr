const { execFile } = require("child_process");
const { promisify } = require("util");
const { loadEnvFile } = require("./loadEnv");

const execFileAsync = promisify(execFile);

loadEnvFile(".env.playwright");

async function getOrgSession(alias) {
  const { stdout } = await execFileAsync(
    "sf",
    ["org", "display", "--target-org", alias, "--json"],
    {
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

  return {
    accessToken: result.accessToken,
    instanceUrl: result.instanceUrl,
    username: result.username
  };
}

function stripAnsi(value) {
  return value
    .replace(/\u001B\[[0-?]*[ -/]*[@-~]/g, "")
    .replace(/^\uFEFF/, "")
    .trim();
}

module.exports = {
  getOrgSession
};
