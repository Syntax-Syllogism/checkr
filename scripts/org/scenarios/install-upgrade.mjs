import gate from "./gate-block-pass.mjs";
import { cleanup } from "../lib/fixtures.mjs";
import { soqlLiteral } from "../lib/apex.mjs";
import {
  assertDisposableOrg,
  checkInstalled,
  deployReferenceShim,
  fixtureSnapshot,
  installPackage,
  workerSave
} from "../lib/install.mjs";

// Installs --upgrade-from, completes a gated checklist through it, upgrades in
// place to --package and checks that the checklist data survives and the gate
// still blocks and passes. Without --upgrade-from it records the upgrade as
// skipped and only proves the gate on --package.
export default {
  name: "install-upgrade",
  description:
    "Installs --upgrade-from, seeds and completes a gated checklist, upgrades to --package, and checks data and gate behavior survive.",
  identities: gate.identities,
  async deploy(ctx) {
    assertDisposableOrg(ctx, "install-upgrade");
    if (!ctx.packageId)
      throw new Error("install-upgrade requires --package <04t>");
    await installPackage(ctx.sfJson, ctx.upgradeFrom ?? ctx.packageId);
  },
  setup(ctx) {
    ctx.metric("upgradeFrom", ctx.upgradeFrom ?? null);
    checkInstalled(
      ctx,
      "starting version installed",
      ctx.upgradeFrom ?? ctx.packageId,
      "scenario/installed-before.json"
    );
    deployReferenceShim(ctx);
    gate.setup(ctx);
  },
  async run(ctx) {
    // Block, complete the checklist, then pass: the seeded template, published
    // version, instance and completed item are what the upgrade must keep.
    gate.run(ctx);
    if (!ctx.upgradeFrom) {
      ctx.metric("upgrade", "skipped: no --upgrade-from version supplied");
      return;
    }
    const seeded = fixtureSnapshot(ctx);
    const upgrade = await installPackage(ctx.sfJson, ctx.packageId);
    const installed = checkInstalled(
      ctx,
      "upgraded in place to the new version",
      ctx.packageId,
      "scenario/installed-after.json"
    );
    ctx.packageVersion(installed?.version ?? ctx.packageId);
    ctx.artifact("scenario/upgrade.json", upgrade);
    ctx.metric("upgrade", "performed");
    const kept = fixtureSnapshot(ctx);
    ctx.artifact("scenario/data-before-after.json", { seeded, kept });
    for (const key of Object.keys(seeded))
      ctx.check(
        `${key} from the first install survive`,
        seeded[key].length > 0 &&
          JSON.stringify(seeded[key]) === JSON.stringify(kept[key]),
        `${seeded[key].length} before, ${kept[key].length} after`
      );

    // The completed checklist still satisfies the gate after the upgrade.
    const [account] = ctx.soql(
      `SELECT Id FROM Account WHERE Name=${soqlLiteral(ctx.fixtureKey + "-0")}`
    );
    const reset = workerSave(ctx, account.Id, "Cold");
    const passed = !reset && !workerSave(ctx, account.Id, "Hot");
    ctx.check(
      "completed checklist still passes the gate after upgrade",
      passed
    );

    // A record without an instance is still blocked by the published version.
    const [worker] = ctx.soql(
      `SELECT Id FROM User WHERE Username=${soqlLiteral(ctx.worker)}`
    );
    ctx.runAnonymous(
      `insert new Account(Name=${soqlLiteral(ctx.fixtureKey + "-1")}, Rating='Cold', OwnerId=${soqlLiteral(worker.Id)});`
    );
    const [fresh] = ctx.soql(
      `SELECT Id FROM Account WHERE Name=${soqlLiteral(ctx.fixtureKey + "-1")}`
    );
    const error = workerSave(ctx, fresh.Id, "Hot");
    ctx.artifact("scenario/blocked-after-upgrade.json", { message: error });
    ctx.check(
      "gate still blocks an incomplete record after upgrade",
      Boolean(error?.includes(`${ctx.fixtureKey} requires completion`)),
      error ?? "save succeeded"
    );
  },
  verify(ctx) {
    ctx.check(
      "upgrade performed or skipped with a reason",
      ctx.metrics.upgrade === "performed" ||
        String(ctx.metrics.upgrade).startsWith("skipped: ")
    );
  },
  cleanup
};
