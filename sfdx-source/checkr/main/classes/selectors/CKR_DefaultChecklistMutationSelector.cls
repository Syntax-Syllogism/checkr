/**
 * Loads visible checklist state for edits and derives rollup query inputs.
 */
public with sharing class CKR_DefaultChecklistMutationSelector
  extends CKR_SelectorBase implements CKR_IChecklistMutationSelector {
  private static final String ITEM_BY_ID_SOQL =
    'SELECT Id, CKR_ChecklistInstance__c, CKR_Required__c, CKR_SourceType__c, CKR_Label__c, '
    + 'CKR_ExplanationRequired__c, CKR_ExplanationInputType__c, CKR_ExplanationPicklistValues__c, '
    + 'CKR_AssigneeUser__c, CKR_CheckboxValue__c, CKR_Explanation__c, CKR_Completed__c, '
    + 'CKR_ChecklistInstance__r.Id, CKR_ChecklistInstance__r.CKR_ParentRecordId__c, '
    + 'CKR_ChecklistInstance__r.CKR_ChecklistTemplateVersion__r.CKR_CompletionAccessMode__c, '
    + 'CKR_ChecklistInstance__r.CKR_ChecklistTemplateVersion__r.CKR_CustomPermissionDeveloperName__c '
    + 'FROM CKR_ChecklistInstanceItem__c WHERE Id = :checklistItemId LIMIT 1';

  private static final String INSTANCE_BY_ID_SOQL =
    'SELECT Id, CKR_ParentRecordId__c, '
    + 'CKR_ChecklistTemplateVersion__r.CKR_CompletionAccessMode__c, '
    + 'CKR_ChecklistTemplateVersion__r.CKR_CustomPermissionDeveloperName__c '
    + 'FROM CKR_ChecklistInstance__c WHERE Id = :checklistInstanceId LIMIT 1';

  private static final String MAX_SORT_SOQL =
    'SELECT MAX(CKR_SortOrder__c) maxSort FROM CKR_ChecklistInstanceItem__c '
    + 'WHERE CKR_ChecklistInstance__c = :checklistInstanceId';

  private static final String INSTANCE_FOR_ROLLUP_SOQL =
    'SELECT Id, CKR_DueDate__c FROM CKR_ChecklistInstance__c WHERE Id = :checklistInstanceId LIMIT 1';

  private static final String REQUIRED_COUNT_SOQL =
    'SELECT COUNT() FROM CKR_ChecklistInstanceItem__c '
    + 'WHERE CKR_ChecklistInstance__c = :checklistInstanceId '
    + 'AND CKR_SourceType__c = \'Template\' AND CKR_Required__c = TRUE';

  private static final String COMPLETED_COUNT_SOQL =
    'SELECT COUNT() FROM CKR_ChecklistInstanceItem__c '
    + 'WHERE CKR_ChecklistInstance__c = :checklistInstanceId '
    + 'AND CKR_SourceType__c = \'Template\' AND CKR_Required__c = TRUE AND CKR_Completed__c = TRUE';

  /**
   * Loads a checklist item and the instance needed to check edit access.
   * @param checklistItemId ID of the checklist item
   * @return visible item with mutation context, or null
   */
  public CKR_ChecklistInstanceItem__c selectChecklistItemById(
    Id checklistItemId
  ) {
    List<CKR_ChecklistInstanceItem__c> items =
      (List<CKR_ChecklistInstanceItem__c>) queryWithBinds(
        ITEM_BY_ID_SOQL,
        new Map<String, Object>{ 'checklistItemId' => checklistItemId }
      );
    return items.isEmpty() ? null : items[0];
  }

  /**
   * Loads the instance and its parent access mode before creating an item.
   * @param checklistInstanceId ID of the checklist instance
   * @return visible instance with mutation context, or null
   */
  public CKR_ChecklistInstance__c selectChecklistInstanceById(
    Id checklistInstanceId
  ) {
    List<CKR_ChecklistInstance__c> instances =
      (List<CKR_ChecklistInstance__c>) queryWithBinds(
        INSTANCE_BY_ID_SOQL,
        instanceBinds(checklistInstanceId)
      );
    return instances.isEmpty() ? null : instances[0];
  }

  /**
   * Determines where a new ad hoc item belongs after existing items.
   * @param checklistInstanceId ID of the checklist instance
   * @return the next sort order for the checklist
   */
  public Decimal selectNextAdHocSortOrder(Id checklistInstanceId) {
    List<AggregateResult> sortResults =
      (List<AggregateResult>) queryWithBinds(
        MAX_SORT_SOQL,
        instanceBinds(checklistInstanceId)
      );
    if (!sortResults.isEmpty() && sortResults[0].get('maxSort') != null) {
      return ((Decimal) sortResults[0].get('maxSort')) + 1;
    }
    return 1;
  }

  /**
   * Loads the values needed to recalculate checklist progress and overdue status.
   * @param checklistInstanceId ID of the checklist instance
   * @return visible instance with rollup context, or null
   */
  public CKR_ChecklistInstance__c selectChecklistInstanceForRollup(
    Id checklistInstanceId
  ) {
    List<CKR_ChecklistInstance__c> instances =
      (List<CKR_ChecklistInstance__c>) queryWithBinds(
        INSTANCE_FOR_ROLLUP_SOQL,
        instanceBinds(checklistInstanceId)
      );
    return instances.isEmpty() ? null : instances[0];
  }

  /**
   * Counts required items copied from the template for gate progress.
   * @param checklistInstanceId ID of the checklist instance
   * @return the number of qualifying items
   */
  public Integer countRequiredTemplateItems(Id checklistInstanceId) {
    return countWithBinds(
      REQUIRED_COUNT_SOQL,
      instanceBinds(checklistInstanceId)
    );
  }

  /**
   * Counts completed required template items for gate progress.
   * @param checklistInstanceId ID of the checklist instance
   * @return the number of qualifying completed items
   */
  public Integer countCompletedRequiredTemplateItems(Id checklistInstanceId) {
    return countWithBinds(
      COMPLETED_COUNT_SOQL,
      instanceBinds(checklistInstanceId)
    );
  }

  private static Map<String, Object> instanceBinds(Id checklistInstanceId) {
    return new Map<String, Object>{
      'checklistInstanceId' => checklistInstanceId
    };
  }
}
