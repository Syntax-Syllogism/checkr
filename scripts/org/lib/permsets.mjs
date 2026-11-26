import { soqlLiteral } from "./apex.mjs";

// Assigning a permission set the user already holds fails with
// "Duplicate PermissionSetAssignment", so a reused evidence org needs these.
export function missingPermissionSets(soql, username, names) {
  if (!names.length) return [];
  const held = new Set(
    soql(
      `SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE Assignee.Username = ${soqlLiteral(username)} AND PermissionSet.Name IN (${names.map(soqlLiteral).join(", ")})`
    ).map((row) => row.PermissionSet?.Name)
  );
  return names.filter((name) => !held.has(name));
}

export function ensureAdminPermset(ctx) {
  const { username } = ctx.sfJson(["org", "display"]).result;
  if (missingPermissionSets(ctx.soql, username, ["CKR_Admin"]).length)
    ctx.sfJson(["org", "assign", "permset", "--name", "CKR_Admin"]);
}
