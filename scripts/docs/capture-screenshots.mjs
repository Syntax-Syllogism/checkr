#!/usr/bin/env node
// Captures the admin guide screenshots from a CheckR scratch org.
//
// Dev tooling only: it needs a live scratch org with the checkr and reference
// packages deployed, so it is not part of `npm test`. Shots and redaction live
// in scripts/docs/shots.json; this file is the runner.
//
// Usage (from the repo root):
//
//   # Capture everything. Seeds scripts/docs/seedDocsData.apex first (a no-op
//   # when the docs template exists), then writes
//   # docs/images/admin-guide/<id>.png in manifest order.
//   npm run docs:screenshots -- --org checkr-evidence
//
//   # Re-capture one shot:
//   npm run docs:screenshots -- --org checkr-evidence --shot record-viewer
//
//   npm run docs:screenshots -- --list     # shots, and which change the org
//
// The org may also come from CKR_DOCS_ORG. Only scratch orgs are accepted,
// because the script seeds data and publishes a version. It never creates,
// resets or deletes an org. Add --headed to watch the browser.
//
// Sign-in opens a one-time frontdoor URL from `sf org open --url-only` as the
// org's default user; no session file is written. Fixed conditions: Chromium, 1440x900 viewport, device
// scale factor 2, light theme, en-US, UTC. Before every capture the page's
// text is redacted: the admin user's name and username, org hosts, and org Ids
// become placeholders, and the avatar is blurred.

import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "@playwright/test";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const IMAGE_DIR = join(ROOT, "docs", "images", "admin-guide");
const MANIFEST = JSON.parse(
  readFileSync(join(ROOT, "scripts", "docs", "shots.json"), "utf8")
);
const SHOTS = new Map(MANIFEST.shots.map((s) => [s.id, s]));

// ---------------------------------------------------------------- arguments

function parseArgs(argv) {
  const args = { org: process.env.CKR_DOCS_ORG };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--org") args.org = argv[++i];
    else if (a === "--shot") (args.shots ??= []).push(argv[++i]);
    else if (a === "--list") args.list = true;
    else if (a === "--headed") args.headed = true;
    else if (a === "--help" || a === "-h") args.help = true;
    else throw new Error(`Unknown argument: ${a}`);
  }
  return args;
}

function listShots() {
  for (const shot of MANIFEST.shots) {
    const note = shot.changesOrg ? " (changes the org)" : "";
    console.log(`${shot.id.padEnd(28)} ${shot.title}${note}`);
  }
}

// ---------------------------------------------------------------- sf helpers

function sf(args, env = {}) {
  try {
    const out = execFileSync("sf", [...args, "--json"], {
      cwd: ROOT,
      encoding: "utf8",
      env: { ...process.env, ...env, FORCE_COLOR: "0", NO_COLOR: "1" },
      stdio: ["ignore", "pipe", "ignore"],
      maxBuffer: 64 * 1024 * 1024
    });
    return JSON.parse(out).result;
  } catch (error) {
    // Never echo stdout: `sf org display` output holds an access token.
    throw new Error(
      `sf ${args.slice(0, 3).join(" ")} failed (${error.status})`
    );
  }
}

function makeOrg(alias) {
  const soql = (query) =>
    sf(["data", "query", "-o", alias, "-q", query]).records;
  const apexFile = (file) => {
    const result = sf(["apex", "run", "-o", alias, "-f", file]);
    if (!result?.success) throw new Error(`Apex failed: ${file}`);
  };
  return { alias, soql, apexFile };
}

function requireScratchOrg(alias) {
  const info = sf(["org", "display", "-o", alias]);
  if (!info.expirationDate) {
    throw new Error(
      `${alias} is not a scratch org; refusing to seed or publish.`
    );
  }
  return info;
}

// ---------------------------------------------------------------- tokens

// {account:Redwood Health} {template:Docs_Account_Onboarding}
// {version:Docs_Account_Onboarding:2} {rule:Industry change gate:1}
// {instance:Redwood Health} {report:CKR_Gate_Bypasses}
// {dashboard:CKR_Checkr_Operations} {supportedObject:Account}
function makeResolver(org) {
  const one = (q, what) => {
    const rows = org.soql(q);
    if (!rows.length) throw new Error(`No record for ${what}`);
    return rows[0].Id;
  };
  const quote = (v) => v.replace(/'/g, "\\'");
  const handlers = {
    account: (name) =>
      one(
        `SELECT Id FROM Account WHERE Name = '${quote(name)}' ORDER BY CreatedDate DESC LIMIT 1`,
        `account ${name}`
      ),
    template: (devName) =>
      one(
        `SELECT Id FROM CKR_ChecklistTemplate__c WHERE CKR_DeveloperName__c = '${quote(devName)}'`,
        `template ${devName}`
      ),
    version: (devName, number) =>
      one(
        `SELECT Id FROM CKR_ChecklistTemplateVersion__c WHERE CKR_ChecklistTemplate__r.CKR_DeveloperName__c = '${quote(devName)}' AND CKR_VersionNumber__c = ${Number(number)}`,
        `version ${devName} ${number}`
      ),
    rule: (name, number) =>
      one(
        `SELECT Id FROM CKR_ChecklistGateRule__c WHERE Name = '${quote(name)}' AND CKR_ChecklistTemplateVersion__r.CKR_VersionNumber__c = ${Number(number)} LIMIT 1`,
        `rule ${name} ${number}`
      ),
    instance: (accountName) =>
      one(
        `SELECT Id FROM CKR_ChecklistInstance__c WHERE CKR_ParentRecordId__c = '${handlers.account(accountName)}' LIMIT 1`,
        `instance on ${accountName}`
      ),
    report: (devName) =>
      one(
        `SELECT Id FROM Report WHERE DeveloperName = '${quote(devName)}'`,
        `report ${devName}`
      ),
    dashboard: (devName) =>
      one(
        `SELECT Id FROM Dashboard WHERE DeveloperName = '${quote(devName)}'`,
        `dashboard ${devName}`
      ),
    supportedObject: (devName) =>
      one(
        `SELECT Id FROM CKR_SupportedObject__mdt WHERE DeveloperName = '${quote(devName)}'`,
        `supported object ${devName}`
      )
  };
  return (text) =>
    text.replace(/\{([a-zA-Z]+):([^}]+)\}/g, (_, kind, rest) =>
      handlers[kind](...rest.split(":"))
    );
}

// ---------------------------------------------------------------- redaction

// Runs in every frame before the page scripts. It replaces the admin user's
// identity and org-specific strings in text nodes and inputs (piercing shadow
// roots), and blurs the avatar.
function redactionScript(config) {
  const { replacements, patterns, blurSelectors } = config;
  const compiled = patterns.map(([re, to]) => [new RegExp(re, "g"), to]);
  const swap = (text) => {
    let out = text;
    for (const [from, to] of replacements) out = out.split(from).join(to);
    for (const [re, to] of compiled) out = out.replace(re, to);
    return out;
  };
  const walk = (root) => {
    const nodes = root.querySelectorAll ? root.querySelectorAll("*") : [];
    const textWalker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    for (let n = textWalker.nextNode(); n; n = textWalker.nextNode()) {
      const next = swap(n.nodeValue);
      if (next !== n.nodeValue) n.nodeValue = next;
    }
    for (const el of nodes) {
      if (el.shadowRoot) walk(el.shadowRoot);
      if (el.matches?.(blurSelectors)) {
        el.style.setProperty("filter", "blur(7px)", "important");
      }
      if (el.tagName === "INPUT" || el.tagName === "TEXTAREA") {
        const next = swap(el.value ?? "");
        if (next !== el.value) el.value = next;
      }
    }
  };
  const run = () => {
    try {
      walk(document);
    } catch {
      // The page is mid-navigation; the next tick will catch up.
    }
  };
  window.__redact = run;
  setInterval(run, 500);
}

function redactionConfig(admin, hosts) {
  const cfg = MANIFEST.redaction;
  const lastFirst = (name) => {
    const parts = (name ?? "").trim().split(/\s+/);
    return parts.length === 2 ? `${parts[1]}, ${parts[0]}` : "";
  };
  return {
    replacements: [
      [admin.username, cfg.adminUsername],
      [admin.name, cfg.adminName],
      [lastFirst(admin.name), lastFirst(cfg.adminName)],
      ...hosts.map((host) => [host, cfg.orgHost])
    ].filter(([from]) => from),
    patterns: cfg.patterns,
    blurSelectors: cfg.blurSelectors.join(",")
  };
}

// ---------------------------------------------------------------- locators

function locate(page, spec, resolveText) {
  let root = spec.frame ? page.frameLocator(spec.frame).first() : page;
  if (spec.within) root = locate(root, spec.within, resolveText);
  const text = (v) => (typeof v === "string" ? resolveText(v) : v);
  let loc;
  if (spec.role) {
    loc = root.getByRole(spec.role, {
      name: text(spec.name),
      exact: spec.exact ?? false
    });
  } else if (spec.text) {
    loc = root.getByText(text(spec.text), { exact: spec.exact ?? false });
  } else if (spec.label) {
    loc = root.getByLabel(text(spec.label), { exact: spec.exact ?? false });
  } else if (spec.css) {
    loc = root.locator(spec.css);
  } else {
    throw new Error(`Bad locator: ${JSON.stringify(spec)}`);
  }
  if (spec.hasText) loc = loc.filter({ hasText: text(spec.hasText) });
  loc = loc.filter({ visible: spec.visible ?? true });
  return spec.nth === undefined ? loc.first() : loc.nth(spec.nth);
}

// -------------------------------------------------------------------- runner

class Runner {
  constructor({ page, org, baseUrl }) {
    this.page = page;
    this.org = org;
    this.baseUrl = baseUrl;
    this.resolve = makeResolver(org);
    this.captured = [];
    this.failed = [];
  }

  async settle() {
    await this.page
      .locator(".slds-spinner_container, lightning-spinner .slds-spinner")
      .first()
      .waitFor({ state: "hidden", timeout: 30000 })
      .catch(() => {});
    await this.page.waitForTimeout(MANIFEST.settleMs);
  }

  async goto(path) {
    const resolved = this.resolve(path);
    try {
      await this.page.goto(this.baseUrl + resolved, { waitUntil: "commit" });
    } catch (error) {
      // Setup pages bounce through the setup domain probe, which interrupts
      // goto but still ends on the requested page.
      if (!/interrupted by another navigation/.test(error.message)) {
        throw error;
      }
    }
    await this.page.waitForLoadState("domcontentloaded");
    await this.settle();
  }

  async capture(shot) {
    const { page } = this;
    await page.evaluate(() => window.__redact?.()).catch(() => {});
    await page.waitForTimeout(MANIFEST.redactWaitMs);
    const path = join(IMAGE_DIR, `${shot.id}.png`);
    const options = { path, animations: "disabled", scale: "device" };
    if (shot.selector) {
      await locate(page, shot.selector, this.resolve).screenshot(options);
    } else {
      await page.screenshot({
        ...options,
        clip: {
          x: 0,
          y: 0,
          width: MANIFEST.viewport.width,
          height: shot.height ?? MANIFEST.viewport.height
        }
      });
    }
    this.captured.push(shot.id);
    console.log(`  captured ${shot.id}`);
  }

  async step(step, shot) {
    const { page } = this;
    if (step.goto) return this.goto(step.goto);
    if (step.click) {
      await locate(page, step.click, this.resolve).click({
        timeout: step.timeout ?? 20000
      });
      return page.waitForTimeout(400);
    }
    if (step.fill) {
      return locate(page, step.fill, this.resolve).fill(
        this.resolve(step.value)
      );
    }
    if (step.press) return page.keyboard.press(step.press);
    if (step.waitFor) {
      return locate(page, step.waitFor, this.resolve).waitFor({
        state: step.state ?? "visible",
        timeout: step.timeout ?? 30000
      });
    }
    if (step.wait) return page.waitForTimeout(step.wait);
    if (step.settle) return this.settle();
    if (step.capture) return this.capture(shot);
    throw new Error(`Unknown step: ${JSON.stringify(step)}`);
  }

  async runShot(shot) {
    console.log(`- ${shot.id}`);
    const { width, height } = MANIFEST.viewport;
    await this.page.setViewportSize({ width, height: shot.height ?? height });
    try {
      for (const step of shot.steps ?? []) await this.step(step, shot);
      if (!(shot.steps ?? []).some((s) => s.capture)) await this.capture(shot);
      for (const step of shot.after ?? []) await this.step(step, shot);
    } finally {
      await this.page.setViewportSize({ width, height });
    }
  }
}

// ---------------------------------------------------------------------- main

// A one-time frontdoor URL for the org's default user. The access token that
// scripts/createPlaywrightAuth.mjs passes to frontdoor.jsp can be rejected by
// newer orgs (the page lands on the login screen), so ask the CLI instead.
// The URL holds a session token: never print it.
function frontdoorUrl(alias) {
  return sf([
    "org",
    "open",
    "-o",
    alias,
    "--url-only",
    "-p",
    "/lightning/page/home"
  ]).url;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(
      readFileSync(new URL(import.meta.url), "utf8")
        .split("\n")
        .slice(1, 29)
        .map((l) => l.replace(/^\/\/ ?/, ""))
        .join("\n")
    );
    return;
  }
  if (args.list) return listShots();
  if (!args.org) throw new Error("Pass --org <alias> or set CKR_DOCS_ORG.");
  for (const id of args.shots ?? []) {
    if (!SHOTS.has(id)) throw new Error(`Unknown shot: ${id}`);
  }

  const info = requireScratchOrg(args.org);
  const org = makeOrg(args.org);
  org.apexFile(join(ROOT, "scripts", "docs", "seedDocsData.apex"));

  mkdirSync(IMAGE_DIR, { recursive: true });
  const browser = await chromium.launch({ headless: !args.headed });
  try {
    const context = await browser.newContext({
      viewport: MANIFEST.viewport,
      deviceScaleFactor: MANIFEST.deviceScaleFactor,
      locale: "en-US",
      timezoneId: "UTC",
      colorScheme: "light"
    });
    const adminRows = org.soql(
      `SELECT Name, Username FROM User WHERE Username = '${info.username}'`
    );
    const admin = { name: adminRows[0].Name, username: adminRows[0].Username };
    const myHost = new URL(info.instanceUrl).host;
    const hosts = [
      myHost,
      myHost.replace(".my.salesforce.com", ".lightning.force.com"),
      myHost.replace(".my.salesforce.com", ".my.salesforce-setup.com")
    ];
    await context.addInitScript(
      redactionScript,
      redactionConfig(admin, [...new Set(hosts)])
    );
    const page = await context.newPage();
    await page.goto(frontdoorUrl(args.org), {
      waitUntil: "domcontentloaded"
    });
    await page.waitForURL(/\/lightning\//, { timeout: 120000 });
    const runner = new Runner({
      page,
      org,
      baseUrl: new URL(page.url()).origin
    });

    const shots = args.shots
      ? args.shots.map((id) => SHOTS.get(id))
      : MANIFEST.shots;
    for (const shot of shots) {
      try {
        await runner.runShot(shot);
      } catch (error) {
        runner.failed.push(shot.id);
        console.error(`  FAILED ${shot.id}: ${error.message.split("\n")[0]}`);
        // Unredacted; kept out of the repo for diagnosis only.
        const debug = join(tmpdir(), `ckr-docs-${shot.id}-failed.png`);
        await page.screenshot({ path: debug }).catch(() => {});
        console.error(`  page: ${new URL(page.url()).pathname}; see ${debug}`);
      }
    }
    console.log(
      `Done: ${runner.captured.length} shot(s) written to ${IMAGE_DIR}`
    );
    if (runner.failed.length) {
      console.error(`Failed shots: ${runner.failed.join(", ")}`);
      process.exitCode = 1;
    }
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
