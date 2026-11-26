/**
 * Publishes a draft and replaces the previous published version under a template lock.
 */
public with sharing class CKR_DefaultTemplateVersionService
  extends CKR_ServiceBase implements CKR_IChecklistTemplateVersionService {
  private static Set<Id> lifecycleWrites = new Set<Id>();
  /**
   * Signals a version that cannot be published in its current state.
   */
  public class PublishException extends Exception {
  }

  /**
   * Checks whether publishing currently authorizes a protected status transition.
   * @param versionId checklist template version ID
   * @return true while the version is in the active cutover
   */
  public static Boolean isLifecycleWrite(Id versionId) {
    return lifecycleWrites.contains(versionId);
  }

  /**
   * Switches the published version and template pointer in one transaction.
   * @param templateVersionId draft version selected for publication
   */
  public void publish(Id templateVersionId) {
    CKR_IChecklistTemplateVersionSelector selector =
      (CKR_IChecklistTemplateVersionSelector) CKR_AppFactory.getInstance(
        CKR_IChecklistTemplateVersionSelector.class
      );
    CKR_ChecklistTemplateVersion__c version =
      lockAndValidateDraft(selector, templateVersionId);
    applyTransitions(version, versionTransitions(selector, version));
  }

  private static CKR_ChecklistTemplateVersion__c lockAndValidateDraft(
    CKR_IChecklistTemplateVersionSelector selector,
    Id templateVersionId
  ) {
    CKR_ChecklistTemplateVersion__c version =
      selector.selectVersion(templateVersionId);
    if (version == null) {
      throw new PublishException('Select an existing draft version.');
    }
    if (selector.lockTemplate(version.CKR_ChecklistTemplate__c) == null) {
      throw new PublishException('The template is unavailable.');
    }
    // Re-read after obtaining the shared parent lock: another publisher may have won.
    version = selector.selectVersion(templateVersionId);
    validatePublishable(selector, version);
    return version;
  }

  private static void validatePublishable(
    CKR_IChecklistTemplateVersionSelector selector,
    CKR_ChecklistTemplateVersion__c version
  ) {
    if (version == null || version.CKR_Status__c != 'Draft') {
      throw new PublishException('Only Draft versions can be published.');
    }
    if (selector.countItems(version.Id) == 0) {
      throw new PublishException('Add at least one item before publishing.');
    }
  }

  private static List<SObject> versionTransitions(
    CKR_IChecklistTemplateVersionSelector selector,
    CKR_ChecklistTemplateVersion__c version
  ) {
    List<SObject> updates = new List<SObject>();
    for (CKR_ChecklistTemplateVersion__c previous : selector.selectPublishedVersions(
      version.CKR_ChecklistTemplate__c
    )) {
      updates.add(
        new CKR_ChecklistTemplateVersion__c(
          Id = previous.Id,
          CKR_Status__c = 'Historical'
        )
      );
    }
    updates.add(
      new CKR_ChecklistTemplateVersion__c(
        Id = version.Id,
        CKR_Status__c = 'Published',
        CKR_PublishedBy__c = UserInfo.getUserId(),
        CKR_PublishedOn__c = System.now()
      )
    );
    return updates;
  }

  private void applyTransitions(
    CKR_ChecklistTemplateVersion__c version,
    List<SObject> updates
  ) {
    Savepoint checkpoint = Database.setSavepoint();
    try {
      for (SObject row : updates) {
        lifecycleWrites.add(row.Id);
      }
      dmlGateway().doUpdate(updates, CKR_DmlMode.ALL_OR_NONE);
      dmlGateway()
        .doUpdate(
          new List<SObject>{
            new CKR_ChecklistTemplate__c(
              Id = version.CKR_ChecklistTemplate__c,
              CKR_CurrentPublishedVersion__c = version.Id
            )
          },
          CKR_DmlMode.ALL_OR_NONE
        );
    } catch (Exception failure) {
      Database.rollback(checkpoint);
      throw failure;
    } finally {
      lifecycleWrites.clear();
    }
  }
}
