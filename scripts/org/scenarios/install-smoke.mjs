import gate from "./gate-block-pass.mjs";
import { cleanup, noOp } from "../lib/fixtures.mjs";
import {
  assertDisposableOrg,
  checkInstalled,
  checkPackageMetadata,
  deployReferenceShim,
  installPackage,
  packageMetadata
} from "../lib/install.mjs";

// Package-only install: this scenario supplies its own deploy step, so the
// harness skips its source deploy and nothing from sfdx-source/checkr is
// deployed to the org. Only the reference Account trigger shim comes from
// source, as a subscriber's own shim would.
export default {
  name: "install-smoke",
  description:
    "Installs --package into a fresh scratch org, checks packaged metadata, deploys the reference shim, and proves a gate block and pass.",
  identities: gate.identities,
  async deploy(ctx) {
    assertDisposableOrg(ctx, "install-smoke");
    if (!ctx.packageId)
      throw new Error("install-smoke requires --package <04t>");
    await installPackage(ctx.sfJson, ctx.packageId);
  },
  setup(ctx) {
    ctx.packageVersion(
      checkInstalled(
        ctx,
        "package version installed",
        ctx.packageId,
        "scenario/installed.json"
      )?.version ?? ctx.packageId
    );
    const metadata = packageMetadata(ctx);
    ctx.artifact("scenario/package-metadata.json", metadata);
    checkPackageMetadata(ctx, metadata);
    deployReferenceShim(ctx);
    ctx.check("reference trigger shim deployed post-install", true);
    gate.setup(ctx);
  },
  run(ctx) {
    gate.run(ctx);
  },
  verify: noOp,
  cleanup
};
