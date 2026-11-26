import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { XMLParser } from "fast-xml-parser";
import {
  crudTable,
  embeddedTable,
  normalizeTable
} from "../permissionSetCrud.mjs";

const root = path.resolve(import.meta.dirname, "../..");
const schemaRoots = [
  "sfdx-source/checkr/main/schema/customObjects/objects",
  "sfdx-source/checkr/main/schema/customMetadataTypes/objects"
].map((dir) => path.join(root, dir));
const parser = new XMLParser();
const read = (file) => readFileSync(file, "utf8");

function loadMetadata() {
  const objects = new Map();
  for (const schemaRoot of schemaRoots) {
    for (const name of readdirSync(schemaRoot)) {
      const base = path.join(schemaRoot, name);
      const object = parser.parse(
        read(path.join(base, `${name}.object-meta.xml`))
      ).CustomObject;
      const fieldDir = path.join(base, "fields");
      const fields = new Map(
        (existsSync(fieldDir) ? readdirSync(fieldDir) : [])
          .filter((file) => file.endsWith(".field-meta.xml"))
          .map((file) => {
            const field = parser.parse(
              read(path.join(fieldDir, file))
            ).CustomField;
            return [
              field.fullName,
              {
                type: field.type,
                required:
                  field.type === "MasterDetail" ||
                  field.required === true ||
                  field.required === "true"
              }
            ];
          })
      );
      objects.set(name, { sharingModel: object.sharingModel, fields });
    }
  }
  return objects;
}

// Each object is a `### \`API_Name\`` section with a `Sharing:` line and a
// field table whose first three columns are API name, type and required.
function parseDoc(text) {
  const objects = new Map();
  const sections = text.split(/^### /m).slice(1);
  for (const section of sections) {
    const name = section.match(/^`([^`]+)`/)?.[1];
    if (!name) continue;
    const sharing = section.match(/^Sharing: (?:`(\w+)`|none)/m);
    const fields = new Map();
    for (const row of section.matchAll(
      /^\|\s*`(\w+)`\s*\|\s*(\w+)\s*\|\s*(Yes|No)\s*\|/gm
    )) {
      assert.ok(!fields.has(row[1]), `${name}.${row[1]} is documented twice`);
      fields.set(row[1], { type: row[2], required: row[3] === "Yes" });
    }
    objects.set(name, {
      sharingModel: sharing ? sharing[1] : null,
      hasSharingLine: Boolean(sharing),
      fields
    });
  }
  return objects;
}

function compare(doc, metadata) {
  const errors = [];
  for (const [name, object] of metadata) {
    const documented = doc.get(name);
    if (!documented) {
      errors.push(`${name} is not documented`);
      continue;
    }
    if (!documented.hasSharingLine) {
      errors.push(`${name} has no Sharing: line`);
    } else if ((documented.sharingModel ?? undefined) !== object.sharingModel) {
      errors.push(
        `${name} sharing is ${object.sharingModel ?? "none"}, doc says ${documented.sharingModel ?? "none"}`
      );
    }
    for (const [field, definition] of object.fields) {
      const entry = documented.fields.get(field);
      if (!entry) {
        errors.push(`${name}.${field} is not documented`);
        continue;
      }
      if (entry.type !== definition.type) {
        errors.push(
          `${name}.${field} type is ${definition.type}, doc says ${entry.type}`
        );
      }
      if (entry.required !== definition.required) {
        errors.push(
          `${name}.${field} required is ${definition.required}, doc says ${entry.required}`
        );
      }
    }
    for (const field of documented.fields.keys()) {
      if (!object.fields.has(field)) {
        errors.push(`${name}.${field} is documented but not in metadata`);
      }
    }
  }
  for (const name of doc.keys()) {
    if (!metadata.has(name)) {
      errors.push(`${name} is documented but not in metadata`);
    }
  }
  return errors;
}

const metadata = loadMetadata();
const doc = parseDoc(read(path.join(root, "docs/object-model.md")));

test("object-model.md matches object and field metadata", () => {
  assert.ok(metadata.has("CKR_SupportedObject__mdt"));
  assert.ok(metadata.size >= 10, `only ${metadata.size} objects loaded`);
  assert.deepEqual(compare(doc, metadata), []);
});

test("an undocumented metadata field is reported", () => {
  const extra = structuredClone(metadata);
  extra
    .get("CKR_ChecklistInstance__c")
    .fields.set("CKR_Dummy__c", { type: "Text", required: false });
  assert.deepEqual(compare(doc, extra), [
    "CKR_ChecklistInstance__c.CKR_Dummy__c is not documented"
  ]);
});

test("a documented field missing from metadata is reported", () => {
  const fewer = structuredClone(metadata);
  fewer.get("CKR_ChecklistTemplate__c").fields.delete("CKR_Active__c");
  assert.deepEqual(compare(doc, fewer), [
    "CKR_ChecklistTemplate__c.CKR_Active__c is documented but not in metadata"
  ]);
});

test("type, required and sharing drift is reported", () => {
  const drift = structuredClone(metadata);
  drift.get("CKR_ChecklistTemplate__c").sharingModel = "Private";
  drift.get("CKR_ChecklistTemplate__c").fields.set("CKR_Active__c", {
    type: "Text",
    required: true
  });
  assert.deepEqual(compare(doc, drift), [
    "CKR_ChecklistTemplate__c sharing is Private, doc says ReadWrite",
    "CKR_ChecklistTemplate__c.CKR_Active__c type is Text, doc says Checkbox",
    "CKR_ChecklistTemplate__c.CKR_Active__c required is true, doc says false"
  ]);
});

test("security.md permission set table matches permission set metadata", () => {
  const embedded = embeddedTable(read(path.join(root, "docs/security.md")));
  assert.ok(embedded, "docs/security.md is missing the crud-table markers");
  assert.equal(
    normalizeTable(embedded),
    normalizeTable(crudTable()),
    "Run `node scripts/permissionSetCrud.mjs --write` to regenerate the table"
  );
});
