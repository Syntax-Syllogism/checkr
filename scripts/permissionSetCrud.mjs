#!/usr/bin/env node
/**
 * Generates the permission set object-access table in docs/security.md from
 * the permission set XML, so the doc cannot drift from metadata.
 *
 *   node scripts/permissionSetCrud.mjs          # print the table
 *   node scripts/permissionSetCrud.mjs --write  # replace it in docs/security.md
 *
 * `scripts/test/object-model.test.mjs` fails when the committed table differs.
 */
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { XMLParser } from "fast-xml-parser";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const permissionSetDir = path.join(
  root,
  "sfdx-source/checkr/main/user/permissionsets"
);
const objectDir = path.join(
  root,
  "sfdx-source/checkr/main/schema/customObjects/objects"
);
export const securityDoc = path.join(root, "docs/security.md");
export const startMarker = "<!-- crud-table:start -->";
export const endMarker = "<!-- crud-table:end -->";

// Assignment order used in the docs, not alphabetical.
const permissionSetOrder = [
  "CKR_Admin",
  "CKR_User",
  "CKR_ReadOnly",
  "CKR_GateBypass",
  "CKR_AuditMaintenance"
];
const list = (value) =>
  value === undefined ? [] : Array.isArray(value) ? value : [value];
const flag = (value) => value === true || value === "true";

function access(permission) {
  if (!permission) return "-";
  const letters = [
    ["allowCreate", "C"],
    ["allowRead", "R"],
    ["allowEdit", "E"],
    ["allowDelete", "D"]
  ]
    .filter(([key]) => flag(permission[key]))
    .map(([, letter]) => letter)
    .join("");
  const all = [
    flag(permission.viewAllRecords) && "VA",
    flag(permission.modifyAllRecords) && "MA"
  ].filter(Boolean);
  return [letters || "-", ...all].join(" ");
}

export function crudTable() {
  const parser = new XMLParser();
  const sets = readdirSync(permissionSetDir)
    .filter((file) => file.endsWith(".permissionset-meta.xml"))
    .map((file) => file.replace(".permissionset-meta.xml", ""))
    .sort(
      (a, b) =>
        (permissionSetOrder.indexOf(a) + 1 || 99) -
          (permissionSetOrder.indexOf(b) + 1 || 99) || a.localeCompare(b)
    );
  const permissions = new Map(
    sets.map((name) => {
      const xml = parser.parse(
        readFileSync(
          path.join(permissionSetDir, `${name}.permissionset-meta.xml`),
          "utf8"
        )
      ).PermissionSet;
      return [
        name,
        new Map(
          list(xml.objectPermissions).map((entry) => [entry.object, entry])
        )
      ];
    })
  );
  const objects = readdirSync(objectDir)
    // Hierarchy custom settings take no object permissions.
    .filter((name) => name !== "CKR_Settings__c")
    .sort();
  const rows = [
    `| Object | ${sets.map((name) => `\`${name}\``).join(" | ")} |`,
    `| --- | ${sets.map(() => "---").join(" | ")} |`,
    ...objects.map(
      (object) =>
        `| \`${object}\` | ${sets
          .map((name) => access(permissions.get(name).get(object)))
          .join(" | ")} |`
    )
  ];
  return rows.join("\n");
}

// Ignores column padding so a prettier-formatted table still matches.
export function normalizeTable(table) {
  return table
    .trim()
    .split("\n")
    .map((line) =>
      line
        .split("|")
        .map((cell) => cell.trim().replace(/^:?-+:?$/, "---"))
        .join("|")
    )
    .join("\n");
}

export function embeddedTable(text) {
  const start = text.indexOf(startMarker);
  const end = text.indexOf(endMarker);
  if (start < 0 || end < start) return null;
  return text.slice(start + startMarker.length, end).trim();
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const table = crudTable();
  if (process.argv.includes("--write")) {
    const text = readFileSync(securityDoc, "utf8");
    if (embeddedTable(text) === null) {
      console.error(
        `Missing ${startMarker} / ${endMarker} in docs/security.md`
      );
      process.exit(1);
    }
    const start = text.indexOf(startMarker) + startMarker.length;
    writeFileSync(
      securityDoc,
      `${text.slice(0, start)}\n\n${table}\n\n${text.slice(text.indexOf(endMarker))}`
    );
  } else {
    console.log(table);
  }
}
