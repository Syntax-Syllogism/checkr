import { randomUUID } from "node:crypto";
import { seed, cleanup, withAuditMaintenance } from "../lib/fixtures.mjs";
import { soqlLiteral } from "../lib/apex.mjs";

export default {
  name: "audit-integrity",
  description:
    "Routine admins cannot rewrite history or cascade-delete it; temporary maintenance permits deliberate changes.",
  identities: [
    {
      key: `audit-${randomUUID().slice(0, 8)}`,
      profile: "Standard Platform User",
      license: "Salesforce Platform",
      permissionSets: ["CKR_Admin"],
      extra: {
        LastName: "CheckR Audit Evidence",
        Alias: "ckraud",
        TimeZoneSidKey: "America/New_York",
        LocaleSidKey: "en_US",
        EmailEncodingKey: "UTF-8",
        LanguageLocaleKey: "en_US"
      }
    }
  ],
  setup(ctx) {
    const username = [...ctx.users.values()][0];
    const [actor] = ctx.soql(
      `SELECT Id FROM User WHERE Username=${soqlLiteral(username)}`
    );
    ctx.auditActor = { username, ...actor };
    seed(ctx, { ownerId: actor.Id });
    ctx.runAnonymous(`
      CKR_ChecklistTemplateVersion__c version=[SELECT Id, CKR_ChecklistTemplate__c FROM CKR_ChecklistTemplateVersion__c WHERE CKR_ChecklistTemplate__r.CKR_DeveloperName__c=${soqlLiteral(ctx.fixtureKey + "_0")}];
      Account parent=[SELECT Id FROM Account WHERE Name=${soqlLiteral(ctx.fixtureKey + "-0")}];
      CKR_ChecklistInstance__c instance=new CKR_ChecklistInstance__c(OwnerId=${soqlLiteral(actor.Id)}, CKR_ChecklistTemplate__c=version.CKR_ChecklistTemplate__c, CKR_ChecklistTemplateVersion__c=version.Id, CKR_ParentRecordId__c=parent.Id, CKR_ParentObjectApiName__c='Account', CKR_UniqueKey__c=parent.Id+'|'+version.CKR_ChecklistTemplate__c);
      insert instance;
      ((CKR_IChecklistAuditService)CKR_AppFactory.getInstance(CKR_IChecklistAuditService.class)).record(new List<CKR_ChecklistAuditEvent__c>{new CKR_ChecklistAuditEvent__c(CKR_ChecklistInstance__c=instance.Id, CKR_EventType__c='ItemCompleted')});
      insert new CKR_GateBypassEvent__c(CKR_RecordId__c=parent.Id, CKR_ObjectApiName__c='Account', CKR_Source__c='CustomPermission', CKR_Actor__c=${soqlLiteral(actor.Id)}, CKR_OccurredOn__c=System.now());
    `);
  },
  run(ctx) {
    const [instance] = ctx.soql(
      `SELECT Id, CKR_ParentRecordId__c FROM CKR_ChecklistInstance__c WHERE CKR_ChecklistTemplate__r.CKR_DeveloperName__c=${soqlLiteral(ctx.fixtureKey + "_0")}`
    );
    const [audit] = ctx.soql(
      `SELECT Id FROM CKR_ChecklistAuditEvent__c WHERE CKR_ChecklistInstance__c=${soqlLiteral(instance.Id)}`
    );
    const [bypass] = ctx.soql(
      `SELECT Id FROM CKR_GateBypassEvent__c WHERE CKR_RecordId__c=${soqlLiteral(instance.CKR_ParentRecordId__c)}`
    );
    ctx.auditBypassId = bypass.Id;
    const mutate = (verb, object, id) =>
      ctx.sfJson([
        "data",
        verb,
        "record",
        "--target-org",
        ctx.auditActor.username,
        "--sobject",
        object,
        "--record-id",
        id,
        ...(verb === "update" ? ["--values", "CKR_Details__c=maintenance"] : [])
      ]);
    for (const [object, row] of [
      ["CKR_ChecklistAuditEvent__c", audit],
      ["CKR_GateBypassEvent__c", bypass]
    ]) {
      for (const verb of ["update", "delete"]) {
        let denied = false;
        try {
          mutate(verb, object, row.Id);
        } catch (error) {
          ctx.artifact(`${object}-${verb}-denied.json`, {
            name: error.name,
            message: error.message
          });
          const label =
            object === "CKR_ChecklistAuditEvent__c"
              ? "Checklist Audit Event"
              : "Gate Bypass Event";
          denied =
            [
              "INSUFFICIENT_ACCESS_OR_READONLY",
              "INVALID_FIELD_FOR_INSERT_UPDATE"
            ].includes(error.name) ||
            error.message.includes("CheckR audit records are append-only") ||
            (verb === "update" &&
              error.name === "CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY" &&
              error.message === `entity type cannot be updated: ${label}`);
        }
        ctx.check(`CKR_Admin cannot ${verb} ${object}`, denied);
      }
    }
    let blocked = false;
    try {
      mutate("delete", "CKR_ChecklistInstance__c", instance.Id);
    } catch (error) {
      blocked = error.message.includes("CheckR audit records are append-only");
    }
    ctx.check("Instance cascade is blocked by the integrity guard", blocked);
    withAuditMaintenance(
      ctx,
      () => {
        mutate("update", "CKR_ChecklistAuditEvent__c", audit.Id);
        mutate("delete", "CKR_ChecklistAuditEvent__c", audit.Id);
        mutate("update", "CKR_GateBypassEvent__c", bypass.Id);
        mutate("delete", "CKR_GateBypassEvent__c", bypass.Id);
      },
      ctx.auditActor.username
    );
    ctx.check(
      "Maintenance deletes both event types",
      ctx.soql(
        `SELECT Id FROM CKR_ChecklistAuditEvent__c WHERE Id=${soqlLiteral(audit.Id)}`
      ).length === 0 &&
        ctx.soql(
          `SELECT Id FROM CKR_GateBypassEvent__c WHERE Id=${soqlLiteral(bypass.Id)}`
        ).length === 0
    );
  },
  verify(ctx) {
    const result = ctx.sfJson([
      "apex",
      "run",
      "test",
      "--tests",
      "CKR_AuditRecordGuardTest",
      "--tests",
      "CKR_AuditMaintenanceIT",
      "--result-format",
      "json",
      "--wait",
      "20"
    ]);
    ctx.artifact("apex-results.json", result);
    ctx.check(
      "Guard and assigned-maintenance Apex tests pass in Salesforce",
      result.result.summary?.outcome === "Passed" &&
        Number(result.result.summary?.testsRan) === 7
    );
  },
  cleanup(ctx) {
    withAuditMaintenance(ctx, () => {
      if (ctx.auditBypassId)
        ctx.runAnonymous(
          `delete [SELECT Id FROM CKR_GateBypassEvent__c WHERE Id=${soqlLiteral(ctx.auditBypassId)}];`
        );
      else if (ctx.fixtureKey) {
        const [parent] = ctx.soql(
          `SELECT Id FROM Account WHERE Name=${soqlLiteral(ctx.fixtureKey + "-0")}`
        );
        if (parent)
          ctx.runAnonymous(
            `delete [SELECT Id FROM CKR_GateBypassEvent__c WHERE CKR_RecordId__c=${soqlLiteral(parent.Id)}];`
          );
      }
      cleanup(ctx);
    });
  }
};
