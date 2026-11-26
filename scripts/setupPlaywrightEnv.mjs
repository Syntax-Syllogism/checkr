import fs from "fs";
import path from "path";
import { execFile } from "child_process";
import { promisify } from "util";
import { fileURLToPath } from "url";

const execFileAsync = promisify(execFile);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

async function runCommand(cmd, args) {
  try {
    const { stdout, stderr } = await execFileAsync(cmd, args, { cwd: repoRoot });
    if (stderr && !stdout) console.error(stderr);
    return stdout;
  } catch (error) {
    if (error.stdout) console.log(error.stdout);
    if (error.stderr) console.error(error.stderr);
    throw error;
  }
}

async function main() {
  const args = process.argv.slice(2);
  const aliasArg = args.find((arg) => !arg.startsWith("-"));

  const envPath = path.join(repoRoot, ".env.playwright");
  ensureEnvFile(envPath);

  let existingAlias = "";
  if (fs.existsSync(envPath)) {
    const content = fs.readFileSync(envPath, "utf8");
    const match = content.match(/^SF_ORG_ALIAS=(.*)/m);
    if (match) {
      existingAlias = match[1].trim();
    }
  }

  const alias =
    aliasArg || existingAlias || process.env.SF_ORG_ALIAS || "checkr";

  process.stdout.write(
    `--- Setting up Playwright environment for org: ${alias} ---\n`
  );

  // 1. Seed users and data in separate transactions
  process.stdout.write("Seeding smoke users...\n");
  await runCommand("sf", [
    "apex",
    "run",
    "--file",
    "scripts/seedSmokeUsers.apex",
    "--target-org",
    alias
  ]);

  process.stdout.write("Seeding smoke data...\n");
  await runCommand("sf", [
    "apex",
    "run",
    "--file",
    "scripts/seedSmokeData.apex",
    "--target-org",
    alias
  ]);

  // 2. Query IDs
  process.stdout.write("Querying record IDs...\n");
  const createRecordQuery =
    "SELECT Id FROM Account WHERE Name = 'Checkr Smoke - No Checklist - Control Record' LIMIT 1";
  const viewerRecordQuery =
    "SELECT Id FROM Account WHERE Name = 'Checkr Smoke - Redwood Health - ReadAccess Template' LIMIT 1";

  const createRecordResult = JSON.parse(
    await runCommand("sf", [
      "data",
      "query",
      "--query",
      createRecordQuery,
      "--target-org",
      alias,
      "--json"
    ])
  );
  const viewerRecordResult = JSON.parse(
    await runCommand("sf", [
      "data",
      "query",
      "--query",
      viewerRecordQuery,
      "--target-org",
      alias,
      "--json"
    ])
  );

  const createRecordId = createRecordResult.result.records[0]?.Id;
  const viewerRecordId = viewerRecordResult.result.records[0]?.Id;

  if (!createRecordId || !viewerRecordId) {
    throw new Error(
      "Failed to find seeded records. Check CheckrSmokeSeed.cls and query filters."
    );
  }

  process.stdout.write(
    `Found IDs: Create=${createRecordId}, Viewer=${viewerRecordId}\n`
  );

  // 3. Write/Update .env.playwright
  let envContent = "";
  if (fs.existsSync(envPath)) {
    envContent = fs.readFileSync(envPath, "utf8");
  }

  const updates = {
    SF_ORG_ALIAS: alias,
    CKR_CREATE_RECORD_ID: createRecordId,
    CKR_VIEWER_RECORD_ID: viewerRecordId
  };

  for (const [key, value] of Object.entries(updates)) {
    const regex = new RegExp(`^${key}=.*`, "m");
    if (envContent.match(regex)) {
      envContent = envContent.replace(regex, `${key}=${value}`);
    } else {
      if (envContent && !envContent.endsWith("\n")) {
        envContent += "\n";
      }
      envContent += `${key}=${value}\n`;
    }
  }

  fs.writeFileSync(envPath, envContent.trim() + "\n");
  process.stdout.write(`Successfully updated ${envPath}\n`);
}

function ensureEnvFile(envPath) {
  if (fs.existsSync(envPath)) {
    return;
  }

  const examplePath = path.join(repoRoot, ".env.playwright.example");
  if (fs.existsSync(examplePath)) {
    fs.copyFileSync(examplePath, envPath);
    process.stdout.write(`Created ${envPath} from ${examplePath}\n`);
    return;
  }

  fs.writeFileSync(envPath, "SF_ORG_ALIAS=checkr\n");
  process.stdout.write(`Created ${envPath}\n`);
}

main().catch((err) => {
  process.stderr.write("\nError during setup:\n");
  process.stderr.write(`${err.message || err}\n`);
  process.exit(1);
});
