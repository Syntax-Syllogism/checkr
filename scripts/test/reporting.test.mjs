import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { XMLParser, XMLValidator } from "fast-xml-parser";

const source = path.resolve("sfdx-source/checkr/main");
const parser = new XMLParser();
const list = (value) =>
  value === undefined ? [] : Array.isArray(value) ? value : [value];
function xml(file) {
  const text = readFileSync(file, "utf8");
  assert.equal(XMLValidator.validate(text), true, `Invalid XML: ${file}`);
  return parser.parse(text);
}
function files(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) =>
    entry.isDirectory()
      ? files(path.join(dir, entry.name))
      : [path.join(dir, entry.name)]
  );
}
const objects = new Map();
for (const dir of readdirSync(
  path.join(source, "schema/customObjects/objects")
)) {
  const base = path.join(source, "schema/customObjects/objects", dir);
  const fields = new Map(
    files(base)
      .filter((f) => f.endsWith(".field-meta.xml"))
      .map((f) => {
        const field = xml(f).CustomField;
        return [field.fullName, field];
      })
  );
  objects.set(dir, {
    fields,
    metadata: xml(path.join(base, `${dir}.object-meta.xml`)).CustomObject
  });
}
const standardFields = new Set([
  "Id",
  "Name",
  "CreatedDate",
  "LastModifiedDate",
  "OwnerId",
  "CreatedById",
  "LastModifiedById"
]);
function fieldAt(object, fieldPath) {
  const [field, ...rest] = fieldPath.split(".");
  assert.ok(objects.has(object), `Unknown object ${object}`);
  const definition = objects.get(object).fields.get(field);
  assert.ok(
    definition || standardFields.has(field),
    `Missing field ${object}.${field}`
  );
  if (rest.length) {
    assert.ok(definition?.referenceTo, `Not a lookup: ${object}.${field}`);
    fieldAt(definition.referenceTo, rest.join("."));
  }
}
function joinedObject(base, relationship) {
  const matches = [...objects].filter(([, object]) =>
    [...object.fields.values()].some(
      (f) =>
        f.referenceTo === base && `${f.relationshipName}__r` === relationship
    )
  );
  assert.equal(
    matches.length,
    1,
    `Unknown/ambiguous relationship ${base}.${relationship}`
  );
  return matches[0][0];
}
function typeColumns(type) {
  assert.equal(
    objects.get(type.baseObject)?.metadata.enableReports,
    true,
    `${type.baseObject} must allow reports`
  );
  const tables = new Map([[type.baseObject, type.baseObject]]);
  let base = type.baseObject;
  let table = base;
  for (let join = type.join; join; join = join.join) {
    base = joinedObject(base, join.relationship);
    table += `.${join.relationship}`;
    tables.set(table, base);
  }
  const columns = new Set();
  for (const section of list(type.sections)) {
    for (const column of list(section.columns)) {
      assert.ok(
        tables.has(column.table),
        `Unknown report table ${column.table}`
      );
      fieldAt(tables.get(column.table), column.field);
      columns.add(`${column.table}$${column.field}`);
    }
  }
  return columns;
}
const reportingFiles = files(path.join(source, "reporting"));
const types = new Map(
  reportingFiles
    .filter((f) => f.endsWith(".reportType-meta.xml"))
    .map((f) => [
      path.basename(f, ".reportType-meta.xml") + "__c",
      xml(f).ReportType
    ])
);
const reports = new Map(
  reportingFiles
    .filter((f) => f.endsWith(".report-meta.xml"))
    .map((f) => [
      `${path.basename(path.dirname(f))}/${path.basename(f, ".report-meta.xml")}`,
      xml(f).Report
    ])
);
function checkReport(report) {
  assert.ok(
    types.has(report.reportType),
    `Unknown report type ${report.reportType}`
  );
  const columns = typeColumns(types.get(report.reportType));
  function visit(value) {
    if (!value || typeof value !== "object") return;
    for (const [key, child] of Object.entries(value)) {
      if (["field", "column", "dateColumn", "sourceColumnName"].includes(key)) {
        assert.ok(
          columns.has(child),
          `Report field not exposed by type: ${child}`
        );
      } else if (Array.isArray(child)) child.forEach(visit);
      else visit(child);
    }
  }
  visit(report);
}

test("every report type field resolves on its actual object, including joins and lookups", () => {
  assert.ok(types.size >= 4);
  for (const type of types.values()) typeColumns(type);
  assert.equal(types.get("CKR_Instances_With_Items__c").join.outerJoin, true);
});
test("every report column, filter, grouping and date field is exposed by its report type", () => {
  assert.equal(reports.size, 3);
  for (const report of reports.values()) checkReport(report);
});
test("checker rejects missing fields, wrong-object fields, broken joins and unexposed report filters", () => {
  assert.throws(
    () => fieldAt("CKR_ChecklistInstance__c", "CKR_Missing__c"),
    /Missing field/
  );
  assert.throws(
    () => fieldAt("CKR_ChecklistInstance__c", "CKR_AssigneeUser__c"),
    /Missing field/
  );
  assert.throws(
    () =>
      fieldAt(
        "CKR_ChecklistAuditEvent__c",
        "CKR_ChecklistInstance__c.CKR_Missing__c"
      ),
    /Missing field/
  );
  assert.throws(
    () => joinedObject("CKR_ChecklistInstance__c", "Missing__r"),
    /relationship/
  );
  const report = structuredClone([...reports.values()][0]);
  report.filter = {
    criteriaItems: { column: "CKR_ChecklistInstance__c$CKR_Missing__c" }
  };
  assert.throws(() => checkReport(report), /not exposed/);
});
test("open checklists count instances once and use creation-age bands", () => {
  const report = reports.get("CKR_Checkr_Operations/CKR_Open_Checklists");
  assert.equal(report.reportType, "CKR_Instances__c");
  assert.equal(types.get(report.reportType).join, undefined);
  assert.deepEqual(report.filter.criteriaItems, {
    column: "CKR_ChecklistInstance__c$CKR_IsComplete__c",
    operator: "equals",
    value: false
  });
  assert.deepEqual(
    list(report.groupingsDown).map((g) => g.field),
    [
      "CKR_ChecklistInstance__c$CKR_ChecklistTemplate__c",
      "CKR_ChecklistInstance__c$CKR_AgeBand__c"
    ]
  );
  const formula = objects
    .get("CKR_ChecklistInstance__c")
    .fields.get("CKR_AgeBand__c").formula;
  assert.match(formula, /TODAY\(\) - DATEVALUE\(CreatedDate\) <= 7/);
  assert.match(formula, /<= 30/);
});
test("age band is readable, not editable, for every checklist permission set", () => {
  for (const name of ["CKR_Admin", "CKR_User", "CKR_ReadOnly"]) {
    const set = xml(
      path.join(source, `user/permissionsets/${name}.permissionset-meta.xml`)
    ).PermissionSet;
    const permission = list(set.fieldPermissions).find(
      (p) => p.field === "CKR_ChecklistInstance__c.CKR_AgeBand__c"
    );
    assert.ok(permission, `${name} is missing CKR_AgeBand__c`);
    assert.equal(permission.readable, true, `${name} cannot read age band`);
    assert.equal(permission.editable, false, `${name} can edit age band`);
  }
});
test("event reports use occurrence dates and last 30 days", () => {
  for (const name of ["CKR_Recent_Audit_Activity", "CKR_Gate_Bypasses"]) {
    const report = reports.get(`CKR_Checkr_Operations/${name}`);
    assert.equal(report.timeFrameFilter.interval, "INTERVAL_LAST30");
    assert.match(report.timeFrameFilter.dateColumn, /\$CKR_OccurredOn__c$/);
  }
});
test("dashboard runs as viewer and references each report exactly once", () => {
  const dashboard = xml(
    reportingFiles.find((f) => f.endsWith(".dashboard-meta.xml"))
  ).Dashboard;
  assert.equal(dashboard.dashboardType, "LoggedInUser");
  assert.equal(dashboard.runningUser, undefined);
  assert.ok(dashboard.leftSection);
  assert.ok(dashboard.rightSection);
  const refs = [
    dashboard.leftSection,
    dashboard.middleSection,
    dashboard.rightSection
  ].flatMap((section) => list(section?.components).map((c) => c.report));
  assert.deepEqual(refs.sort(), [...reports.keys()].sort());
  for (const file of reportingFiles.filter((f) => /Folder-meta.xml$/.test(f))) {
    const folder = Object.values(xml(file)).find((v) => typeof v === "object");
    assert.equal(folder.accessType, "Public");
    assert.equal(folder.publicFolderAccess, "ReadOnly");
  }
});
