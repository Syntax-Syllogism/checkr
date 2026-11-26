import { seed, cleanup, readMetrics, noOp } from "../lib/fixtures.mjs";
import { soqlLiteral } from "../lib/apex.mjs";

export function verifyCutover(ctx, result) {
  ctx.artifact("version-cutover.json", result);
  ctx.check(
    "Completed v1 instance still saves after v2 publish",
    result.completedSaved === true
  );
  ctx.check(
    "No-instance record is blocked by v2",
    result.newBlocked === true &&
      result.errors?.some((error) =>
        error.includes(ctx.fixtureKey + " v2 requires completion")
      )
  );
  ctx.check(
    "Exactly one Published version and old version Historical",
    result.publishedCount === 1 && result.oldStatus === "Historical"
  );
  ctx.check(
    "Published rule edits are rejected",
    result.ruleEditRejected === true
  );
}

export default {
  name: "version-cutover",
  description:
    "Publish v2 while retaining v1 instance rules and enforcing v2 for new records.",
  setup: (ctx) => seed(ctx, { count: 2 }),
  run(ctx) {
    const result = readMetrics(
      ctx.runAnonymous(`
      String key=${soqlLiteral(ctx.fixtureKey)};
      String developerName=key+'_0';
      CKR_ChecklistTemplate__c template=[SELECT Id, CKR_CurrentPublishedVersion__c FROM CKR_ChecklistTemplate__c WHERE CKR_DeveloperName__c=:developerName];
      List<Account> accounts=[SELECT Id, Rating FROM Account WHERE Name LIKE :key+'%' ORDER BY Name];
      Id v1=template.CKR_CurrentPublishedVersion__c;
      CKR_ChecklistInstanceCreateRequest request=new CKR_ChecklistInstanceCreateRequest();
      request.parentRecordId=accounts[0].Id; request.parentObjectApiName='Account'; request.templateId=template.Id;
      CKR_ChecklistInstanceCreateResult created=((CKR_IChecklistInstanceService)CKR_AppFactory.getInstance(CKR_IChecklistInstanceService.class)).createFromTemplate(request);
      System.Assert.isTrue(created.success,String.join(created.messages,'; '));
      CKR_ChecklistInstanceItem__c item=[SELECT Id FROM CKR_ChecklistInstanceItem__c WHERE CKR_ChecklistInstance__c=:created.checklistInstanceId LIMIT 1];
      CKR_ChecklistItemUpdateRequest itemUpdate=new CKR_ChecklistItemUpdateRequest(); itemUpdate.checklistItemId=item.Id; itemUpdate.checkboxValue=true; CKR_ChecklistViewerController.updateChecklistItem(itemUpdate);
      System.Assert.isTrue([SELECT CKR_IsComplete__c FROM CKR_ChecklistInstance__c WHERE Id=:created.checklistInstanceId].CKR_IsComplete__c,'Complete v1 before cutover');
      CKR_ChecklistTemplateVersion__c v2=new CKR_ChecklistTemplateVersion__c(CKR_ChecklistTemplate__c=template.Id,CKR_Status__c='Draft',CKR_VersionNumber__c=2,CKR_CompletionAccessMode__c='EditAccess'); insert v2;
      insert new CKR_ChecklistTemplateItem__c(CKR_ChecklistTemplateVersion__c=v2.Id,CKR_Label__c='Stricter review',CKR_Required__c=true,CKR_ExplanationInputType__c='Text');
      CKR_ChecklistGateRule__c rule=new CKR_ChecklistGateRule__c(CKR_ChecklistTemplateVersion__c=v2.Id,CKR_Active__c=true,CKR_ProtectedActionType__c='AnyFieldValueChange',CKR_TargetFieldApiName__c='Rating',CKR_ErrorMessage__c=key+' v2 requires completion'); insert rule;
      ((CKR_IChecklistTemplateVersionService)CKR_AppFactory.getInstance(CKR_IChecklistTemplateVersionService.class)).publish(v2.Id);
      accounts[0].Rating='Hot'; accounts[1].Rating='Hot';
      Database.SaveResult first=Database.update(accounts[0],false);
      Database.SaveResult second=Database.update(accounts[1],false);
      List<String> errors=new List<String>(); for(Database.Error error:second.getErrors()) errors.add(error.getMessage());
      rule.CKR_ErrorMessage__c='Forbidden edit'; Database.SaveResult edited=Database.update(rule,false);
      System.debug('CKR_EVIDENCE='+JSON.serialize(new Map<String,Object>{
        'completedSaved'=>first.isSuccess(), 'newBlocked'=>!second.isSuccess(), 'errors'=>errors,
        'publishedCount'=>[SELECT COUNT() FROM CKR_ChecklistTemplateVersion__c WHERE CKR_ChecklistTemplate__c=:template.Id AND CKR_Status__c='Published'],
        'oldStatus'=>[SELECT CKR_Status__c FROM CKR_ChecklistTemplateVersion__c WHERE Id=:v1].CKR_Status__c,
        'ruleEditRejected'=>!edited.isSuccess()}));
    `)
    );
    verifyCutover(ctx, result);
  },
  verify: noOp,
  cleanup
};
