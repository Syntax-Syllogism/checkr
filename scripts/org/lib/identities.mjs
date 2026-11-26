import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { soqlLiteral } from "./apex.mjs";
import { missingPermissionSets } from "./permsets.mjs";

export function usernameFor(key, orgId) {
  if (!/^[a-z][a-z0-9-]{0,39}$/.test(key))
    throw new Error(
      "Identity key must be lowercase letters, digits or hyphens (max 40)"
    );
  if (!/^00D[a-zA-Z0-9]{12}(?:[a-zA-Z0-9]{3})?$/.test(orgId))
    throw new Error("Invalid org ID");
  return `${key}.${orgId.slice(0, 15)}@checkr-evidence.test`;
}

export function createIdentities({ sfJson, soql, org, orgId, users }) {
  const createdUsers = [];
  const addedPermissions = [];
  function ensureUser({
    key,
    profile,
    license,
    permissionSets = [],
    extra = {}
  }) {
    const username = usernameFor(key, orgId);
    const profiles = soql(
      `SELECT Id, UserLicense.Name FROM Profile WHERE Name = ${soqlLiteral(profile)} AND UserLicense.Name = ${soqlLiteral(license)}`
    );
    if (profiles.length !== 1)
      throw new Error(
        `Profile/license combination not found for identity ${key}`
      );
    const existing = soql(
      `SELECT Id, ProfileId, IsActive FROM User WHERE Username = ${soqlLiteral(username)}`
    );
    if (
      existing.length &&
      (existing[0].ProfileId !== profiles[0].Id || !existing[0].IsActive)
    ) {
      throw new Error(
        `Existing identity ${key} has a different profile or is inactive`
      );
    }
    if (!existing.length) {
      const dir = mkdtempSync(join(tmpdir(), "checkr-user-"));
      try {
        const file = join(dir, "user.json");
        writeFileSync(
          file,
          JSON.stringify({
            ...extra,
            username,
            email: username,
            profileId: profiles[0].Id
          }),
          { mode: 0o600 }
        );
        // create user authenticates a separate CLI session automatically.
        sfJson([
          "org",
          "create",
          "user",
          "--target-org",
          org,
          "--definition-file",
          file
        ]);
      } finally {
        rmSync(dir, { recursive: true, force: true });
      }
    }
    if (!existing.length) createdUsers.push(username);
    // Fail clearly on a reused org whose local per-user auth is missing.
    sfJson(["org", "display", "--target-org", username]);
    const missing = missingPermissionSets(soql, username, permissionSets);
    if (missing.length) {
      addedPermissions.push({ username, names: missing });
      sfJson([
        "org",
        "assign",
        "permset",
        "--target-org",
        org,
        ...missing.flatMap((name) => ["--name", name]),
        "--on-behalf-of",
        username
      ]);
    }
    users.set(key, username);
    return { key, license, permissionSets };
  }
  ensureUser.cleanup = () => {
    for (const { username, names } of addedPermissions) {
      for (const row of soql(
        `SELECT Id FROM PermissionSetAssignment WHERE Assignee.Username = ${soqlLiteral(username)} AND PermissionSet.Name IN (${names.map(soqlLiteral).join(",")})`
      )) {
        sfJson([
          "data",
          "delete",
          "record",
          "--target-org",
          org,
          "--sobject",
          "PermissionSetAssignment",
          "--record-id",
          row.Id
        ]);
      }
    }
    // Salesforce users cannot be deleted. Deactivate only users this run created.
    for (const username of createdUsers) {
      const [user] = soql(
        `SELECT Id FROM User WHERE Username = ${soqlLiteral(username)}`
      );
      if (user)
        sfJson([
          "data",
          "update",
          "record",
          "--target-org",
          org,
          "--sobject",
          "User",
          "--record-id",
          user.Id,
          "--values",
          "IsActive=false"
        ]);
    }
  };
  return ensureUser;
}
