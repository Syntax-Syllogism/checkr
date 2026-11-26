/**
 * Applies viewer edits and builds the user-mode update payload.
 */
public inherited sharing class CKR_ChecklistItemMutation {
  // A user-mode update fails when the record carries fields the user cannot
  // write (e.g. the master-detail parent), so send only the fields this flow
  // changes.
  /**
   * Builds a minimal update payload containing only the editable item fields.
   * @param itemRecord item holding the values to apply or persist
   * @return item Id and the fields allowed in user-mode DML
   */
  public static CKR_ChecklistInstanceItem__c itemChanges(
    CKR_ChecklistInstanceItem__c itemRecord
  ) {
    return new CKR_ChecklistInstanceItem__c(
      Id = itemRecord.Id,
      CKR_CheckboxValue__c = itemRecord.CKR_CheckboxValue__c,
      CKR_Explanation__c = itemRecord.CKR_Explanation__c,
      CKR_AssigneeUser__c = itemRecord.CKR_AssigneeUser__c,
      CKR_Label__c = itemRecord.CKR_Label__c,
      CKR_ExplanationInputType__c = itemRecord.CKR_ExplanationInputType__c,
      CKR_ExplanationPicklistValues__c =
        itemRecord.CKR_ExplanationPicklistValues__c,
      CKR_ExplanationRequired__c = itemRecord.CKR_ExplanationRequired__c
    );
  }

  /**
   * Checks that the item editor supplied the ID needed to load the item.
   * @param request values from the update action
   */
  public static void validateUpdateRequest(
    CKR_ChecklistItemUpdateRequest request
  ) {
    if (request == null || request.checklistItemId == null) {
      throw new AuraHandledException('A checklist item is required.');
    }
  }

  /**
   * Applies the editor values and updates completion state.
   * @param itemRecord item loaded for the edit
   * @param request validated values from the update action
   */
  public static void applyUpdate(
    CKR_ChecklistInstanceItem__c itemRecord,
    CKR_ChecklistItemUpdateRequest request
  ) {
    itemRecord.CKR_CheckboxValue__c = request.checkboxValue == true;
    itemRecord.CKR_Explanation__c = request.explanation;
    itemRecord.CKR_AssigneeUser__c = request.assigneeUserId;
    applyAdHocMetadata(itemRecord, request);
    stampCompletion(itemRecord);
  }

  private static void applyAdHocMetadata(
    CKR_ChecklistInstanceItem__c itemRecord,
    CKR_ChecklistItemUpdateRequest request
  ) {
    if (itemRecord.CKR_SourceType__c != 'AdHoc') {
      return;
    }

    if (request.label != null) {
      if (String.isBlank(request.label)) {
        throw new AuraHandledException('An ad hoc item label is required.');
      }
      itemRecord.CKR_Label__c = request.label.trim();
    }

    itemRecord.CKR_ExplanationInputType__c =
      normalizeExplanationInputType(request.explanationInputType);
    itemRecord.CKR_ExplanationPicklistValues__c =
      itemRecord.CKR_ExplanationInputType__c == 'Picklist'
      ? request.explanationPicklistValues
      : null;
    itemRecord.CKR_ExplanationRequired__c = request.explanationRequired == true;
  }

  /**
   * Recalculates completion and sets or clears the completing user and timestamp.
   * @param itemRecord item holding the values to apply or persist
   */
  private static void stampCompletion(CKR_ChecklistInstanceItem__c itemRecord) {
    itemRecord.CKR_Completed__c = isItemComplete(itemRecord);

    if (itemRecord.CKR_Completed__c) {
      itemRecord.CKR_CompletedBy__c = UserInfo.getUserId();
      itemRecord.CKR_CompletedOn__c = System.now();
      return;
    }

    itemRecord.CKR_CompletedBy__c = null;
    itemRecord.CKR_CompletedOn__c = null;
  }

  /**
   * Normalizes missing and unknown explanation types to text.
   * @param explanationInputType type value supplied by the item or request
   * @return Picklist for picklist items, or Text otherwise
   */
  public static String normalizeExplanationInputType(
    String explanationInputType
  ) {
    return explanationInputType == 'Picklist' ? 'Picklist' : 'Text';
  }

  private static Boolean isItemComplete(
    CKR_ChecklistInstanceItem__c itemRecord
  ) {
    Boolean valueSatisfied = itemRecord.CKR_CheckboxValue__c == true;
    Boolean explanationSatisfied =
      itemRecord.CKR_ExplanationRequired__c != true
      || !String.isBlank(itemRecord.CKR_Explanation__c);
    return valueSatisfied && explanationSatisfied;
  }
  /**
   * Checks the checklist and label before doing record lookups.
   * @param request incoming values for the ad hoc item
   */
  public static void validateAdHocRequest(CKR_AdHocItemRequest request) {
    if (request == null || request.checklistInstanceId == null) {
      throw new AuraHandledException('A checklist instance is required.');
    }
    if (String.isBlank(request.label)) {
      throw new AuraHandledException('An ad hoc item label is required.');
    }
  }

  /**
   * Builds the optional item at its assigned position in the checklist.
   * @param request validated values from the item editor
   * @param nextSortOrder position after existing items
   * @return item ready for user-mode insertion
   */
  public static CKR_ChecklistInstanceItem__c buildAdHocItem(
    CKR_AdHocItemRequest request,
    Decimal nextSortOrder
  ) {
    String normalizedExplanationInputType =
      normalizeExplanationInputType(request.explanationInputType);
    return new CKR_ChecklistInstanceItem__c(
      CKR_ChecklistInstance__c = request.checklistInstanceId,
      CKR_SourceType__c = 'AdHoc',
      CKR_LockedFromTemplate__c = false,
      CKR_Label__c = request.label.trim(),
      CKR_ExplanationRequired__c = request.explanationRequired == true,
      CKR_ExplanationInputType__c = normalizedExplanationInputType,
      CKR_ExplanationPicklistValues__c =
        normalizedExplanationInputType == 'Picklist'
        ? request.explanationPicklistValues
        : null,
      CKR_AssigneeUser__c = request.assigneeUserId,
      CKR_CheckboxValue__c = false,
      CKR_SortOrder__c = nextSortOrder
    );
  }
}
