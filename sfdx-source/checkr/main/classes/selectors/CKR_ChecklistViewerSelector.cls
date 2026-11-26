/**
 * Loads visible checklist instances and items for the record-page viewer.
 */
public with sharing class CKR_ChecklistViewerSelector
  extends CKR_SelectorBase implements CKR_IChecklistViewerSelector {
  private static final String INSTANCES_SOQL =
    'SELECT Id, Name, Owner.Name, CKR_ParentRecordId__c, CKR_IsComplete__c, '
    + 'CKR_IsOverdue__c, CKR_PercentComplete__c, CKR_DueDate__c, '
    + 'CKR_ChecklistTemplate__r.Name, '
    + 'CKR_ChecklistTemplateVersion__r.CKR_CompletionAccessMode__c, '
    + 'CKR_ChecklistTemplateVersion__r.CKR_CustomPermissionDeveloperName__c '
    + 'FROM CKR_ChecklistInstance__c '
    + 'WHERE CKR_ParentRecordId__c = :parentRecordId '
    + 'ORDER BY CreatedDate DESC';

  private static final String ITEMS_SOQL =
    'SELECT Id, CKR_ChecklistInstance__c, CKR_Label__c, CKR_SourceType__c, '
    + 'CKR_Required__c, CKR_ExplanationRequired__c, CKR_ExplanationInputType__c, '
    + 'CKR_ExplanationPicklistValues__c, CKR_AssigneeUser__c, CKR_Completed__c, '
    + 'CKR_CheckboxValue__c, CKR_Explanation__c '
    + 'FROM CKR_ChecklistInstanceItem__c '
    + 'WHERE CKR_ChecklistInstance__c IN :checklistInstanceIds '
    + 'ORDER BY CKR_Completed__c ASC, CKR_Required__c DESC, CKR_SortOrder__c ASC, CreatedDate DESC';

  /**
   * Loads the caller’s visible checklist instances for one parent record.
   * @param parentRecordId parent record ID as stored on checklist instances
   * @return checklist instances attached to the parent
   */
  public List<CKR_ChecklistInstance__c> selectInstancesByParentRecordId(
    String parentRecordId
  ) {
    if (String.isBlank(parentRecordId)) {
      return new List<CKR_ChecklistInstance__c>();
    }

    return (List<CKR_ChecklistInstance__c>) queryWithBinds(
      INSTANCES_SOQL,
      new Map<String, Object>{ 'parentRecordId' => parentRecordId }
    );
  }

  /**
   * Loads visible items for every checklist shown on the record page.
   * @param checklistInstanceIds IDs of the checklists to display
   * @return checklist items ordered for display
   */
  public List<CKR_ChecklistInstanceItem__c> selectItemsByChecklistInstanceIds(
    Set<Id> checklistInstanceIds
  ) {
    if (checklistInstanceIds == null || checklistInstanceIds.isEmpty()) {
      return new List<CKR_ChecklistInstanceItem__c>();
    }

    return (List<CKR_ChecklistInstanceItem__c>) queryWithBinds(
      ITEMS_SOQL,
      new Map<String, Object>{ 'checklistInstanceIds' => checklistInstanceIds }
    );
  }
}
