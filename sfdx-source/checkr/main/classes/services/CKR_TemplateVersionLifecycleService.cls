/**
 * Protects published configuration from direct API and UI writes.
 */
public with sharing class CKR_TemplateVersionLifecycleService
  extends CKR_ServiceBase implements CKR_ITemplateVersionLifecycleService {
  /**
   * Guards lifecycle status and snapshot fields on version insert and update.
   * @param records trigger records being checked
   * @param oldMap previous template versions keyed by ID
   */
  public void validateVersions(
    List<CKR_ChecklistTemplateVersion__c> records,
    Map<Id, CKR_ChecklistTemplateVersion__c> oldMap
  ) {
    for (CKR_ChecklistTemplateVersion__c row : records) {
      CKR_ChecklistTemplateVersion__c previous =
        oldMap == null ? null : oldMap.get(row.Id);
      if (CKR_DefaultTemplateVersionService.isLifecycleWrite(row.Id)) {
        continue;
      }
      if (previous != null && previous.CKR_Status__c != 'Draft') {
        row.addError(
          'Published and Historical versions are read-only. Create a Draft version.'
        );
      } else if (row.CKR_Status__c != 'Draft') {
        row.addError('Use Publish Version to publish a Draft version.');
      }
    }
  }
  /**
   * Rejects direct deletion of versions that are no longer drafts.
   * @param records trigger records being checked
   */
  public void validateDeletes(List<SObject> records) {
    Set<Id> versionIds = new Set<Id>();
    for (SObject row : records) {
      versionIds.add(
        row.getSObjectType() == CKR_ChecklistTemplateVersion__c.SObjectType
        ? row.Id
        : (Id) row.get('CKR_ChecklistTemplateVersion__c')
      );
    }
    CKR_IChecklistTemplateVersionSelector selector =
      (CKR_IChecklistTemplateVersionSelector) CKR_AppFactory.getInstance(
        CKR_IChecklistTemplateVersionSelector.class
      );
    Map<Id, CKR_ChecklistTemplateVersion__c> versions =
      new Map<Id, CKR_ChecklistTemplateVersion__c>(
        selector.selectVersions(versionIds)
      );
    for (SObject row : records) {
      Id versionId =
        row.getSObjectType() == CKR_ChecklistTemplateVersion__c.SObjectType
        ? row.Id
        : (Id) row.get('CKR_ChecklistTemplateVersion__c');
      if (
        !versions.containsKey(versionId)
        || versions.get(versionId).CKR_Status__c != 'Draft'
      ) {
        row.addError(
          'Published and Historical configuration cannot be deleted.'
        );
      }
    }
  }
}
