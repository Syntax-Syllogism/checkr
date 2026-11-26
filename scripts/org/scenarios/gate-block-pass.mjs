import { randomUUID } from "node:crypto";
import { seed, cleanup, noOp } from "../lib/fixtures.mjs";
import { soqlLiteral } from "../lib/apex.mjs";

export default {
  name: "gate-block-pass",
  description:
    "A CKR_User is blocked until a required checklist item is completed.",
  identities: [
    {
      key: `worker-${randomUUID().slice(0, 8)}`,
      profile: "Standard User",
      license: "Salesforce",
      permissionSets: ["CKR_User"],
      extra: {
        LastName: "Checkr Evidence",
        Alias: "ckrevid",
        TimeZoneSidKey: "America/New_York",
        LocaleSidKey: "en_US",
        EmailEncodingKey: "UTF-8",
        LanguageLocaleKey: "en_US"
      }
    }
  ],
  setup(ctx) {
    const username = [...ctx.users.values()][0];
    const [user] = ctx.soql(
      `SELECT Id FROM User WHERE Username=${soqlLiteral(username)}`
    );
    seed(ctx, { ownerId: user.Id });
    ctx.worker = username;
  },
  run(ctx) {
    const [account] = ctx.soql(
      `SELECT Id FROM Account WHERE Name=${soqlLiteral(ctx.fixtureKey + "-0")}`
    );
    const update = () =>
      ctx.sfJson([
        "data",
        "update",
        "record",
        "--target-org",
        ctx.worker,
        "--sobject",
        "Account",
        "--record-id",
        account.Id,
        "--values",
        "Rating=Hot"
      ]);
    let blocked = false;
    try {
      update();
    } catch (error) {
      ctx.artifact(
        "blocked-error.json",
        error.payload ?? { message: error.message }
      );
      ctx.metric("exactError", error.message);
      blocked = error.message.includes(ctx.fixtureKey + " requires completion");
    }
    ctx.check("CKR_User blocked with exact gate error", blocked);
    if (!blocked)
      throw new Error(
        "Expected gate error; refusing to claim a block/pass baseline"
      );
    ctx.runAnonymous(`
      String key=${soqlLiteral(ctx.fixtureKey + "_0")};
      CKR_ChecklistTemplate__c template=[SELECT Id FROM CKR_ChecklistTemplate__c WHERE CKR_DeveloperName__c=:key];
      CKR_ChecklistInstanceCreateRequest request=new CKR_ChecklistInstanceCreateRequest();
      request.parentRecordId=${soqlLiteral(account.Id)}; request.parentObjectApiName='Account'; request.templateId=template.Id;
      CKR_ChecklistInstanceCreateResult created=((CKR_IChecklistInstanceService)CKR_AppFactory.getInstance(CKR_IChecklistInstanceService.class)).createFromTemplate(request);
      System.Assert.isTrue(created.success, String.join(created.messages,'; '));
      CKR_ChecklistInstanceItem__c item=[SELECT Id FROM CKR_ChecklistInstanceItem__c WHERE CKR_ChecklistInstance__c=:created.checklistInstanceId LIMIT 1];
      CKR_ChecklistViewerController.updateChecklistItem(item.Id,true,null,null,null,null,null,null);
      CKR_ChecklistInstance__c instance=[SELECT CKR_IsComplete__c FROM CKR_ChecklistInstance__c WHERE Id=:created.checklistInstanceId];
      System.Assert.isTrue(instance.CKR_IsComplete__c, 'Completion must reach the gate');
    `);
    ctx.artifact("allowed-result.json", update());
    const [saved] = ctx.soql(
      `SELECT Rating FROM Account WHERE Id=${soqlLiteral(account.Id)}`
    );
    ctx.check(
      "CKR_User save succeeds after completion",
      saved.Rating === "Hot"
    );
  },
  verify: noOp,
  cleanup
};
