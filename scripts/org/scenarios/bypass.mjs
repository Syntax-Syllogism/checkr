import { randomUUID } from "node:crypto";
import { seed, cleanup, noOp, withAuditMaintenance } from "../lib/fixtures.mjs";
import { soqlLiteral } from "../lib/apex.mjs";

export function verifyBypass(
  ctx,
  events,
  { recordId, actorId, ruleId, source }
) {
  ctx.artifact(`${source}-events.json`, events);
  ctx.check(
    `${source} writes exactly one complete bypass event`,
    events.length === 1 &&
      events[0].CKR_Actor__c === actorId &&
      events[0].CKR_RecordId__c === recordId &&
      events[0].CKR_GateRule__c === ruleId &&
      events[0].CKR_ObjectApiName__c === "Account" &&
      events[0].CKR_Source__c === source &&
      Boolean(events[0].CKR_OccurredOn__c) &&
      Boolean(events[0].CKR_Details__c)
  );
}

export default {
  name: "bypass",
  description:
    "Real API saves through each bypass switch, with complete audit rows and an unprivileged blocked baseline.",
  identities: ["permission", "setting"].map((kind) => ({
    key: `${kind}-${randomUUID().slice(0, 8)}`,
    profile: "Standard Platform User",
    license: "Salesforce Platform",
    permissionSets: kind === "permission" ? ["CKR_GateBypass"] : [],
    extra: {
      LastName: "Checkr Bypass Evidence",
      Alias: "ckrbyp",
      TimeZoneSidKey: "America/New_York",
      LocaleSidKey: "en_US",
      EmailEncodingKey: "UTF-8",
      LanguageLocaleKey: "en_US"
    }
  })),
  setup(ctx) {
    ctx.bypassUsers = [...ctx.users.values()].map((username) => ({
      username,
      ...ctx.soql(
        `SELECT Id FROM User WHERE Username=${soqlLiteral(username)}`
      )[0]
    }));
    seed(ctx, { ownerId: ctx.bypassUsers[0].Id });
    ctx.runAnonymous(
      `insert new Account(Name=${soqlLiteral(ctx.fixtureKey + "-setting")}, Rating='Cold', OwnerId=${soqlLiteral(ctx.bypassUsers[1].Id)});`
    );
  },
  run(ctx) {
    const [rule] = ctx.soql(
      `SELECT Id FROM CKR_ChecklistGateRule__c WHERE CKR_ChecklistTemplateVersion__r.CKR_ChecklistTemplate__r.CKR_DeveloperName__c=${soqlLiteral(ctx.fixtureKey + "_0")}`
    );
    for (const [index, source] of [
      "CustomPermission",
      "CustomSetting"
    ].entries()) {
      const actor = ctx.bypassUsers[index];
      const [account] = ctx.soql(
        `SELECT Id FROM Account WHERE Name=${soqlLiteral(ctx.fixtureKey + (index === 0 ? "-0" : "-setting"))}`
      );
      const update = (rating) =>
        ctx.sfJson([
          "data",
          "update",
          "record",
          "--target-org",
          actor.username,
          "--sobject",
          "Account",
          "--record-id",
          account.Id,
          "--values",
          `Rating=${rating}`
        ]);
      if (index === 1) {
        let blocked = false;
        try {
          update("Hot");
        } catch (error) {
          blocked = error.message.includes(
            ctx.fixtureKey + " requires completion"
          );
        }
        ctx.check("No bypass switch blocks with the gate error", blocked);
        if (!blocked)
          throw new Error("Expected gate block before enabling the setting");
      }
      // Both switches on for the permission user proves precedence in a real org.
      ctx.runAnonymous(
        `insert new CKR_Settings__c(SetupOwnerId=${soqlLiteral(actor.Id)}, CKR_BypassGate__c=true);`
      );
      ctx.artifact(`${source}-save.json`, update("Hot"));
      const [saved] = ctx.soql(
        `SELECT Rating FROM Account WHERE Id=${soqlLiteral(account.Id)}`
      );
      ctx.check(`${source} persists blocked update`, saved.Rating === "Hot");
      update("Warm"); // Allowed transition must not add audit noise.
      const events = ctx.soql(
        `SELECT CKR_Actor__c, CKR_RecordId__c, CKR_ObjectApiName__c, CKR_GateRule__c, CKR_Source__c, CKR_OccurredOn__c, CKR_Details__c FROM CKR_GateBypassEvent__c WHERE CKR_RecordId__c=${soqlLiteral(account.Id)}`
      );
      verifyBypass(ctx, events, {
        recordId: account.Id,
        actorId: actor.Id,
        ruleId: rule.Id,
        source
      });
    }
  },
  verify: noOp,
  cleanup(ctx) {
    if (ctx.bypassUsers)
      ctx.runAnonymous(
        `Set<Id> actors=new Set<Id>{${ctx.bypassUsers.map((user) => soqlLiteral(user.Id)).join(",")}}; delete [SELECT Id FROM CKR_Settings__c WHERE SetupOwnerId IN :actors];`
      );
    if (ctx.fixtureKey)
      withAuditMaintenance(ctx, () =>
        ctx.runAnonymous(
          `String prefix=${soqlLiteral(ctx.fixtureKey + "%")}; Set<Id> accounts=new Map<Id,Account>([SELECT Id FROM Account WHERE Name LIKE :prefix]).keySet(); Set<String> recordIds=new Set<String>(); for(Id recordId:accounts) recordIds.add(String.valueOf(recordId)); delete [SELECT Id FROM CKR_GateBypassEvent__c WHERE CKR_RecordId__c IN :recordIds];`
        )
      );
    cleanup(ctx);
  }
};
