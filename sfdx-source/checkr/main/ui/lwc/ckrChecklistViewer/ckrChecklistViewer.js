import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getRecordChecklists from "@salesforce/apex/CKR_ChecklistViewerController.getRecordChecklists";
import updateChecklistItem from "@salesforce/apex/CKR_ChecklistViewerController.updateChecklistItem";
import addAdHocItem from "@salesforce/apex/CKR_ChecklistViewerController.addAdHocItem";
import removeAdHocItem from "@salesforce/apex/CKR_ChecklistViewerController.removeAdHocItem";
import { refreshApex } from "@salesforce/apex";
import mockChecklistViewerData from "./ckrChecklistViewerMockData";

/**
 * Record-page component that renders checklist instances and item work controls.
 */
export default class CkrChecklistViewer extends LightningElement {
  @api recordId;
  @api title = "CheckR Checklist Viewer";
  @api showMockDataToggle = false;

  checklists = [];
  isLoading = true;
  loadErrorMessage;
  savingItemIds = {};
  savingChecklistIds = {};
  adHocDraftsByChecklistId = {};
  collapsedChecklistIds = {};
  wiredChecklistsResult;
  selectedItem;
  activeAdHocChecklistId;
  _mockDataEnabled = false;

  /**
   * @returns {boolean} true when the component should use local fixture data
   */
  @api
  get useMockData() {
    return this._mockDataEnabled;
  }

  /**
   * Enables or disables local fixture data.
   *
   * @param {boolean|string} value boolean or string boolean from App Builder
   */
  set useMockData(value) {
    this._mockDataEnabled = this.normalizeBoolean(value);
    this.applyCurrentDataSource();
  }

  /**
   * @returns {boolean} true when the component should use local fixture data
   */
  @api
  get mockDataEnabled() {
    return this._mockDataEnabled;
  }

  /**
   * Enables or disables local fixture data.
   *
   * @param {boolean|string} value boolean or string boolean from App Builder
   */
  set mockDataEnabled(value) {
    this._mockDataEnabled = this.normalizeBoolean(value);
    this.applyCurrentDataSource();
  }

  /**
   * Applies mock data immediately when configured before component connection.
   */
  connectedCallback() {
    if (this._mockDataEnabled) {
      this.applyCurrentDataSource();
    }
  }

  /**
   * Loads checklist data from Apex unless mock data is active.
   *
   * @param {object} result wire result from getRecordChecklists
   */
  @wire(getRecordChecklists, { recordId: "$effectiveRecordId" })
  wiredResponse(result) {
    this.wiredChecklistsResult = result;
    if (this._mockDataEnabled) {
      return;
    }

    const { data, error } = result;
    this.isLoading = false;

    if (data) {
      this.loadErrorMessage = null;
      this.checklists = this.normalizeChecklists(data.checklists || []);
      return;
    }

    if (error) {
      this.checklists = [];
      this.loadErrorMessage =
        error?.body?.message ||
        error?.message ||
        "Unable to load checklists for this record.";
    }
  }

  /**
   * @returns {string|undefined} record id passed to Apex, or undefined when using mock data
   */
  get effectiveRecordId() {
    return this._mockDataEnabled ? undefined : this.recordId;
  }

  /**
   * @returns {string} title shown in the component header
   */
  get cardTitle() {
    return this.title;
  }

  /**
   * @returns {boolean} true when normalized checklist data is available
   */
  get hasChecklists() {
    return this.checklists.length > 0;
  }

  /**
   * @returns {boolean} true when the Apex load failed
   */
  get hasLoadError() {
    return Boolean(this.loadErrorMessage);
  }

  /**
   * @returns {boolean} true when an item details panel should be shown
   */
  get hasSelectedItem() {
    return Boolean(this.selectedItem);
  }

  /**
   * @returns {string|null} selected checklist item id
   */
  get selectedItemId() {
    return this.selectedItem?.checklistItemId || null;
  }

  /**
   * @returns {string} selected item panel title
   */
  get selectedItemTitle() {
    return this.selectedItem?.label || "Checklist Item Details";
  }

  /**
   * @returns {boolean} true when the ad hoc composer is open for a checklist
   */
  get hasActiveAdHocChecklist() {
    return Boolean(this.activeAdHocChecklist);
  }

  /**
   * @returns {object|null} checklist currently showing the ad hoc composer
   */
  get activeAdHocChecklist() {
    return (
      this.checklists.find(
        (checklist) =>
          checklist.checklistInstanceId === this.activeAdHocChecklistId
      ) || null
    );
  }

  /**
   * @returns {boolean} true when the development mock-data toggle should render
   */
  get shouldShowMockDataToggle() {
    return this.normalizeBoolean(this.showMockDataToggle);
  }

  /**
   * @returns {string} label describing whether live or mock data is shown
   */
  get dataSourceLabel() {
    return this._mockDataEnabled ? "Mock Data" : "Live Data";
  }

  /**
   * Normalizes boolean API values from App Builder and tests.
   *
   * @param {boolean|string} value value to normalize
   * @returns {boolean} true for boolean true or string "true"
   */
  normalizeBoolean(value) {
    return value === true || value === "true";
  }

  /**
   * Applies the current live/mock data-source mode to component state.
   */
  applyCurrentDataSource() {
    if (this._mockDataEnabled) {
      this.isLoading = false;
      this.loadErrorMessage = null;
      this.checklists = this.normalizeChecklists(this.cloneMockChecklists());
      return;
    }

    this.checklists = [];
    this.loadErrorMessage = null;
    this.isLoading = true;
  }

  /**
   * @returns {Array<object>} deep clone of local mock checklist data
   */
  cloneMockChecklists() {
    return JSON.parse(JSON.stringify(mockChecklistViewerData.checklists || []));
  }

  /**
   * Handles the development toggle between live Apex data and mock data.
   *
   * @param {CustomEvent} event toggle change event
   */
  handleDataSourceToggle(event) {
    this._mockDataEnabled = event.target.checked === true;
    this.applyCurrentDataSource();
  }

  /**
   * Adds view-only UI state to checklist records returned by Apex or mock data.
   *
   * @param {Array<object>} checklists raw checklist summaries
   * @returns {Array<object>} checklist summaries enriched for rendering
   */
  normalizeChecklists(checklists) {
    return checklists.map((checklist) => {
      const adHocDraft = this.getAdHocDraft(checklist.checklistInstanceId);
      const checklistIsSaving = this.isChecklistSaving(
        checklist.checklistInstanceId
      );
      const items = checklist.items || [];
      const metrics = this.calculateChecklistMetrics(items);
      return {
        ...checklist,
        contentId: `checklist-content-${checklist.checklistInstanceId}`,
        isOpen: !this.isChecklistCollapsed(checklist.checklistInstanceId),
        toggleIconName: this.isChecklistCollapsed(checklist.checklistInstanceId)
          ? "utility:chevronright"
          : "utility:chevrondown",
        requiredCompletionCountLabel: `${metrics.requiredCompletedCount}/${metrics.requiredItemCount} required`,
        totalCompletionCountLabel: `${metrics.totalCompletedCount}/${metrics.totalItemCount} total`,
        ownerName: checklist.ownerName || "Unassigned",
        canEditItems: checklist.canEditItems === true,
        isSaving: checklistIsSaving,
        addButtonLabel: checklistIsSaving ? "Adding..." : "Add Item",
        newAdHocLabel: adHocDraft.label,
        newAdHocExplanationInputType: adHocDraft.explanationInputType,
        newAdHocExplanationPicklistValues: adHocDraft.explanationPicklistValues,
        newAdHocPicklistOptionDraft: adHocDraft.picklistOptionDraft,
        newAdHocPicklistOptions: this.parsePicklistOptions(
          adHocDraft.explanationPicklistValues
        ).map((option) => ({
          ...option,
          key: `${checklist.checklistInstanceId}-${option.value}`
        })),
        newAdHocExplanationRequired: adHocDraft.explanationRequired === true,
        showAdHocExplanationPicklistValues:
          adHocDraft.explanationInputType === "Picklist",
        explanationInputTypeOptions: [
          { label: "Text", value: "Text" },
          { label: "Picklist", value: "Picklist" }
        ],
        items: items.map((item) => {
          const itemIsSaving = this.isItemSaving(item.checklistItemId);
          const itemIsComplete = this.isItemCompleteForDisplay(item);
          const itemIsDisabled =
            item.canEdit !== true || checklistIsSaving || itemIsSaving;
          const itemCanDelete = item.isAdHoc === true && !itemIsDisabled;
          const explanationInputType =
            item.explanationInputType === "Picklist" ? "Picklist" : "Text";
          return {
            ...item,
            checkboxValue: this.isItemChecked(item),
            explanationInputType,
            isSaving: itemIsSaving,
            saveStatusText: itemIsSaving ? "Saving changes..." : null,
            isAdHoc: item.isAdHoc === true,
            canEdit: item.canEdit === true,
            isDisabled: itemIsDisabled,
            requiredLabel: item.required ? "REQUIRED" : "OPTIONAL",
            showStatusIcon: itemIsComplete,
            statusIconName: "utility:success",
            statusIconVariant: "success",
            deleteShadeClass: itemCanDelete
              ? "checklist-item__delete-shade"
              : "checklist-item__delete-shade checklist-item__delete-shade_disabled",
            deleteButtonClass: itemCanDelete
              ? "checklist-item__remove"
              : "checklist-item__remove checklist-item__remove_disabled",
            deleteButtonVariant: itemCanDelete
              ? "bare-inverse"
              : "border-filled",
            deleteDisabled: !itemCanDelete,
            deleteTitle: itemCanDelete
              ? "Delete item"
              : "Delete is disabled on this item",
            rowClass: `checklist-item${itemIsComplete ? " checklist-item_complete" : ""}`,
            labelClass: `checklist-item__label${itemIsComplete ? " checklist-item__label_complete" : ""}`,
            explanationRequired: item.explanationRequired === true,
            explanationPlaceholder: "Enter details...",
            usesTextExplanation: explanationInputType === "Text",
            usesPicklistExplanation: explanationInputType === "Picklist",
            explanationPicklistOptions: this.parsePicklistOptions(
              item.explanationPicklistValues
            )
          };
        })
      };
    });
  }

  /**
   * Calculates visible completion counters for a checklist.
   *
   * @param {Array<object>} items checklist items
   * @returns {object} total and required completion counts
   */
  calculateChecklistMetrics(items) {
    const totalItemCount = items.length;
    const totalCompletedCount = items.filter((item) =>
      this.isItemCompleteForDisplay(item)
    ).length;
    const requiredItems = items.filter((item) => item.required === true);
    const requiredItemCount = requiredItems.length;
    const requiredCompletedCount = requiredItems.filter((item) =>
      this.isItemCompleteForDisplay(item)
    ).length;

    return {
      totalItemCount,
      totalCompletedCount,
      requiredItemCount,
      requiredCompletedCount
    };
  }

  /**
   * Checks whether an item should render as checked.
   *
   * @param {object} item checklist item summary
   * @returns {boolean} true when the item is checked or completed
   */
  isItemChecked(item) {
    return item.checkboxValue === true || item.completed === true;
  }

  /**
   * Checks whether an item should render with completed styling.
   *
   * @param {object} item checklist item summary
   * @returns {boolean} true when the item is complete for display purposes
   */
  isItemCompleteForDisplay(item) {
    return this.isItemChecked(item);
  }

  /**
   * Checks whether an item currently has a save request in progress.
   *
   * @param {string} itemId checklist item id
   * @returns {boolean} true when the item is saving
   */
  isItemSaving(itemId) {
    return this.savingItemIds[itemId] === true;
  }

  /**
   * Checks whether a checklist currently has an add-item request in progress.
   *
   * @param {string} checklistId checklist instance id
   * @returns {boolean} true when the checklist is saving
   */
  isChecklistSaving(checklistId) {
    return this.savingChecklistIds[checklistId] === true;
  }

  /**
   * Checks whether a checklist section is collapsed.
   *
   * @param {string} checklistId checklist instance id
   * @returns {boolean} true when the checklist is collapsed
   */
  isChecklistCollapsed(checklistId) {
    return this.collapsedChecklistIds[checklistId] === true;
  }

  /**
   * Converts a delimited picklist value string into lightning-combobox options.
   *
   * @param {string} values newline, comma, or semicolon-delimited values
   * @returns {Array<object>} combobox options
   */
  parsePicklistOptions(values) {
    return (values || "")
      .split(/[,\n;]+/)
      .map((value) => value.trim())
      .filter((value) => value)
      .map((value) => ({ label: value, value }));
  }

  /**
   * Finds a checklist item in the currently rendered checklist state.
   *
   * @param {string} itemId checklist item id
   * @returns {object|null} matching item, if present
   */
  findItem(itemId) {
    for (const checklist of this.checklists) {
      const item = (checklist.items || []).find(
        (checklistItem) => checklistItem.checklistItemId === itemId
      );
      if (item) {
        return item;
      }
    }
    return null;
  }

  /**
   * Applies a saved item update to local mock data.
   *
   * @param {object} updatedItem updated checklist item values
   */
  updateMockItem(updatedItem) {
    this.checklists = this.normalizeChecklists(
      this.checklists.map((checklist) => ({
        ...checklist,
        items: (checklist.items || []).map((item) => {
          return item.checklistItemId === updatedItem.checklistItemId
            ? { ...item, ...updatedItem }
            : item;
        })
      }))
    );
  }

  /**
   * Adds an ad hoc item to local mock data.
   *
   * @param {string} checklistId checklist instance id
   * @param {object} draft ad hoc item draft values
   */
  addMockAdHocItem(checklistId, draft) {
    const nextItemId = `mock-ad-hoc-${Date.now()}`;
    this.checklists = this.normalizeChecklists(
      this.checklists.map((checklist) => {
        if (checklist.checklistInstanceId !== checklistId) {
          return checklist;
        }

        return {
          ...checklist,
          items: [
            ...(checklist.items || []),
            {
              checklistItemId: nextItemId,
              label: draft.label.trim(),
              required: false,
              completed: false,
              checkboxValue: false,
              explanation: "",
              explanationInputType:
                draft.explanationInputType === "Picklist" ? "Picklist" : "Text",
              explanationPicklistValues:
                draft.explanationInputType === "Picklist"
                  ? draft.explanationPicklistValues || null
                  : null,
              assigneeUserId: null,
              assigneeName: null,
              canEdit: true,
              isAdHoc: true,
              explanationRequired: draft.explanationRequired === true
            }
          ]
        };
      })
    );
  }

  /**
   * Removes an ad hoc item from local mock data.
   *
   * @param {string} itemId checklist item id
   */
  removeMockAdHocItem(itemId) {
    this.checklists = this.normalizeChecklists(
      this.checklists.map((checklist) => ({
        ...checklist,
        items: (checklist.items || []).filter(
          (item) => item.checklistItemId !== itemId
        )
      }))
    );
  }

  /**
   * Returns the draft ad hoc item state for a checklist.
   *
   * @param {string} checklistId checklist instance id
   * @returns {object} draft values for the checklist
   */
  getAdHocDraft(checklistId) {
    return (
      this.adHocDraftsByChecklistId[checklistId] || {
        label: "",
        explanationInputType: "Text",
        explanationPicklistValues: "",
        picklistOptionDraft: "",
        explanationRequired: false
      }
    );
  }

  /**
   * Merges changes into a checklist's ad hoc item draft and projected UI state.
   *
   * @param {string} checklistId checklist instance id
   * @param {object} changes changed draft fields
   */
  updateAdHocDraft(checklistId, changes) {
    const nextDraft = {
      ...this.getAdHocDraft(checklistId),
      ...changes
    };
    this.adHocDraftsByChecklistId = {
      ...this.adHocDraftsByChecklistId,
      [checklistId]: nextDraft
    };
    this.checklists = this.checklists.map((checklist) => {
      return checklist.checklistInstanceId === checklistId
        ? {
            ...checklist,
            newAdHocLabel: nextDraft.label,
            newAdHocExplanationInputType: nextDraft.explanationInputType,
            newAdHocExplanationPicklistValues:
              nextDraft.explanationPicklistValues,
            newAdHocPicklistOptionDraft: nextDraft.picklistOptionDraft,
            newAdHocPicklistOptions: this.parsePicklistOptions(
              nextDraft.explanationPicklistValues
            ).map((option) => ({
              ...option,
              key: `${checklistId}-${option.value}`
            })),
            newAdHocExplanationRequired: nextDraft.explanationRequired === true,
            showAdHocExplanationPicklistValues:
              nextDraft.explanationInputType === "Picklist"
          }
        : checklist;
    });
  }

  /**
   * Rebuilds derived UI fields for the current checklist state.
   */
  syncChecklistState() {
    this.checklists = this.normalizeChecklists(this.checklists);
  }

  /**
   * Expands or collapses a checklist section.
   *
   * @param {CustomEvent} event section header click event
   */
  handleToggleChecklistSection(event) {
    const checklistId = event.currentTarget.dataset.checklistId;
    if (!checklistId) {
      return;
    }

    this.collapsedChecklistIds = {
      ...this.collapsedChecklistIds,
      [checklistId]: !this.isChecklistCollapsed(checklistId)
    };
    this.syncChecklistState();
  }

  /**
   * Handles checklist checkbox changes and persists the item.
   *
   * @param {CustomEvent} event checkbox change event
   */
  handleCheckboxChange(event) {
    const itemId = event.target.dataset.itemId;
    const item = this.findItem(itemId);
    if (!item || item.canEdit !== true) {
      return;
    }

    item.completed = event.target.checked;
    item.checkboxValue = event.target.checked;
    this.saveChecklistItem(item);
  }

  /**
   * Handles picklist explanation changes and persists the item.
   *
   * @param {CustomEvent} event explanation combobox change event
   */
  handleExplanationPicklistChange(event) {
    const itemId = event.target.dataset.itemId;
    const item = this.findItem(itemId);
    if (!item || item.canEdit !== true) {
      return;
    }

    item.explanation = event.detail.value;
    this.saveChecklistItem(item);
  }

  /**
   * Handles text explanation blur and persists the item.
   *
   * @param {FocusEvent} event explanation input blur event
   */
  handleExplanationBlur(event) {
    const itemId = event.target.dataset.itemId;
    const item = this.findItem(itemId);
    if (!item || item.canEdit !== true) {
      return;
    }

    item.explanation = event.target.value;
    this.saveChecklistItem(item);
  }

  /**
   * Opens the item details quick-action panel for a checklist item.
   *
   * @param {CustomEvent} event item label click event
   */
  handleOpenItemDetails(event) {
    const itemId =
      event.currentTarget?.dataset?.itemId || event.target.dataset.itemId;
    const item = this.findItem(itemId);
    if (!item) {
      return;
    }

    this.selectedItem = item;
  }

  /**
   * Closes the item details quick-action panel.
   */
  handleCloseItemDetails() {
    this.selectedItem = null;
  }

  /**
   * Submits the item details record-edit form.
   */
  handleSaveItemDetails() {
    this.template.querySelector(".checklist-detail-form")?.submit();
  }

  /**
   * Handles successful item details save and refreshes checklist data.
   *
   * @returns {Promise<void>}
   */
  async handleItemDetailsSuccess() {
    this.selectedItem = null;
    await refreshApex(this.wiredChecklistsResult);
  }

  /**
   * Shows a toast for item details save failures.
   *
   * @param {object} error record-edit-form error event or error-like object
   */
  handleItemDetailsError(error) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Checklist Item Save Failed",
        message:
          error?.detail?.message ||
          error?.body?.message ||
          error?.message ||
          "Unable to save checklist item details.",
        variant: "error"
      })
    );
  }

  /**
   * Updates a field in the active ad hoc item draft.
   *
   * @param {CustomEvent} event draft field change event
   */
  handleAdHocDraftChange(event) {
    const checklistId =
      event.currentTarget?.dataset?.checklistId ||
      event.target.dataset.checklistId;
    const fieldName =
      event.currentTarget?.dataset?.fieldName || event.target.dataset.fieldName;
    if (!checklistId || !fieldName) {
      return;
    }

    const nextValue =
      fieldName === "explanationRequired"
        ? event.target.checked
        : (event.detail?.value ?? event.target.value);
    this.updateAdHocDraft(checklistId, { [fieldName]: nextValue });
  }

  /**
   * Adds a draft picklist option when Enter is pressed.
   *
   * @param {KeyboardEvent} event picklist option keydown event
   */
  handlePicklistOptionKeydown(event) {
    if (event.key !== "Enter") {
      return;
    }

    event.preventDefault();
    this.addDraftPicklistOption(
      event.currentTarget?.dataset?.checklistId ||
        event.target.dataset.checklistId
    );
  }

  /**
   * Adds the current draft picklist option for an ad hoc item.
   *
   * @param {CustomEvent} event add-option button event
   */
  handleAddPicklistOption(event) {
    this.addDraftPicklistOption(
      event.currentTarget?.dataset?.checklistId ||
        event.target.dataset.checklistId
    );
  }

  /**
   * Removes a draft picklist option for an ad hoc item.
   *
   * @param {CustomEvent} event pill remove event
   */
  handleRemovePicklistOption(event) {
    const checklistId =
      event.currentTarget?.dataset?.checklistId ||
      event.target.dataset.checklistId;
    const optionValue = event.target.name;
    if (!checklistId || !optionValue) {
      return;
    }

    const draft = this.getAdHocDraft(checklistId);
    const nextOptions = this.parsePicklistOptions(
      draft.explanationPicklistValues
    )
      .map((option) => option.value)
      .filter((value) => value !== optionValue);
    this.updateAdHocDraft(checklistId, {
      explanationPicklistValues: nextOptions.join("\n")
    });
  }

  /**
   * Adds a non-duplicate picklist option to an ad hoc item draft.
   *
   * @param {string} checklistId checklist instance id
   */
  addDraftPicklistOption(checklistId) {
    if (!checklistId) {
      return;
    }

    const draft = this.getAdHocDraft(checklistId);
    const optionValue = (draft.picklistOptionDraft || "").trim();
    if (!optionValue) {
      return;
    }

    const currentOptions = this.parsePicklistOptions(
      draft.explanationPicklistValues
    ).map((option) => option.value);
    const optionExists = currentOptions.some(
      (value) => value.toLowerCase() === optionValue.toLowerCase()
    );
    const nextOptions = optionExists
      ? currentOptions
      : [...currentOptions, optionValue];

    this.updateAdHocDraft(checklistId, {
      explanationPicklistValues: nextOptions.join("\n"),
      picklistOptionDraft: ""
    });
  }

  /**
   * Cancels ad hoc item entry and resets the draft.
   *
   * @param {CustomEvent} event cancel button event
   */
  handleCancelAdHoc(event) {
    const checklistId =
      event.currentTarget?.dataset?.checklistId ||
      event.target.dataset.checklistId;
    const resetDraft = {
      label: "",
      explanationInputType: "Text",
      explanationPicklistValues: "",
      picklistOptionDraft: "",
      explanationRequired: false
    };
    if (!checklistId) {
      const section = event.target.closest("[data-checklist-id]");
      if (section) {
        this.updateAdHocDraft(section.dataset.checklistId, resetDraft);
      }
      return;
    }
    this.updateAdHocDraft(checklistId, resetDraft);
    if (this.activeAdHocChecklistId === checklistId) {
      this.activeAdHocChecklistId = null;
    }
  }

  /**
   * Opens the ad hoc item composer for a checklist.
   *
   * @param {CustomEvent} event open composer event
   */
  handleOpenAdHocComposer(event) {
    const checklistId =
      event.currentTarget?.dataset?.checklistId ||
      event.target.dataset.checklistId;
    if (!checklistId) {
      return;
    }

    this.activeAdHocChecklistId = checklistId;
  }

  /**
   * Closes the active ad hoc item composer.
   */
  handleCloseAdHocComposer() {
    this.activeAdHocChecklistId = null;
  }

  /**
   * Creates an ad hoc checklist item from the active draft.
   *
   * @param {CustomEvent} event add item button event
   * @returns {Promise<void>}
   */
  async handleAddAdHocItem(event) {
    const checklistId =
      event.currentTarget?.dataset?.checklistId ||
      event.target.dataset.checklistId;
    if (!checklistId) {
      return;
    }

    const draft = this.getAdHocDraft(checklistId);
    if (!draft.label || !draft.label.trim()) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Item Required",
          message: "Enter a label before adding the item.",
          variant: "error"
        })
      );
      return;
    }

    this.savingChecklistIds = {
      ...this.savingChecklistIds,
      [checklistId]: true
    };
    this.syncChecklistState();

    try {
      if (this._mockDataEnabled) {
        this.addMockAdHocItem(checklistId, draft);
        this.updateAdHocDraft(checklistId, {
          label: "",
          explanationInputType: "Text",
          explanationPicklistValues: "",
          picklistOptionDraft: "",
          explanationRequired: false
        });
        this.activeAdHocChecklistId = null;
        return;
      }

      await addAdHocItem({
        request: {
          checklistInstanceId: checklistId,
          label: draft.label,
          explanationInputType: draft.explanationInputType,
          explanationPicklistValues: draft.explanationPicklistValues || null,
          explanationRequired: draft.explanationRequired === true,
          assigneeUserId: null
        }
      });
      this.updateAdHocDraft(checklistId, {
        label: "",
        explanationInputType: "Text",
        explanationPicklistValues: "",
        picklistOptionDraft: "",
        explanationRequired: false
      });
      this.activeAdHocChecklistId = null;
      await refreshApex(this.wiredChecklistsResult);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Add Item Failed",
          message:
            error?.body?.message || error?.message || "Unable to add the item.",
          variant: "error"
        })
      );
    } finally {
      this.savingChecklistIds = {
        ...this.savingChecklistIds,
        [checklistId]: false
      };
      this.syncChecklistState();
    }
  }

  /**
   * Removes an editable ad hoc checklist item.
   *
   * @param {CustomEvent} event remove item button event
   * @returns {Promise<void>}
   */
  async handleRemoveAdHocItem(event) {
    const itemId = event.target.dataset.itemId;
    const item = this.findItem(itemId);
    if (!item || item.canEdit !== true || item.isAdHoc !== true) {
      return;
    }

    this.savingItemIds = {
      ...this.savingItemIds,
      [item.checklistItemId]: true
    };
    this.syncChecklistState();

    try {
      if (this._mockDataEnabled) {
        this.removeMockAdHocItem(item.checklistItemId);
        return;
      }

      await removeAdHocItem({ checklistItemId: item.checklistItemId });
      await refreshApex(this.wiredChecklistsResult);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Remove Item Failed",
          message:
            error?.body?.message ||
            error?.message ||
            "Unable to remove the item.",
          variant: "error"
        })
      );
    } finally {
      this.savingItemIds = {
        ...this.savingItemIds,
        [item.checklistItemId]: false
      };
      this.syncChecklistState();
    }
  }

  /**
   * Persists checklist item answer, explanation, and ad hoc metadata changes.
   *
   * @param {object} item checklist item summary
   * @returns {Promise<void>}
   */
  async saveChecklistItem(item) {
    if (!item || item.canEdit !== true) {
      return;
    }

    this.savingItemIds = {
      ...this.savingItemIds,
      [item.checklistItemId]: true
    };
    this.syncChecklistState();

    try {
      if (this._mockDataEnabled) {
        this.updateMockItem({
          ...item,
          completed: this.isItemComplete(item)
        });
        return;
      }

      await updateChecklistItem({
        request: {
          checklistItemId: item.checklistItemId,
          checkboxValue: item.checkboxValue || false,
          explanation: item.explanation || null,
          label: item.isAdHoc ? item.label || null : null,
          explanationInputType: item.isAdHoc
            ? item.explanationInputType || "Text"
            : null,
          explanationPicklistValues:
            item.isAdHoc && item.explanationInputType === "Picklist"
              ? item.explanationPicklistValues || null
              : null,
          explanationRequired: item.isAdHoc
            ? item.explanationRequired === true
            : false,
          assigneeUserId: item.assigneeUserId || null
        }
      });
      await refreshApex(this.wiredChecklistsResult);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Checklist Update Failed",
          message:
            error?.body?.message ||
            error?.message ||
            "Unable to save checklist item.",
          variant: "error"
        })
      );
    } finally {
      this.savingItemIds = {
        ...this.savingItemIds,
        [item.checklistItemId]: false
      };
      this.syncChecklistState();
    }
  }

  /**
   * Evaluates whether an item is complete using the same client-side rules used for mock data.
   *
   * @param {object} item checklist item summary
   * @returns {boolean} true when the item is checked and any required explanation is present
   */
  isItemComplete(item) {
    return (
      item.checkboxValue === true &&
      (item.explanationRequired !== true || Boolean(item.explanation))
    );
  }
}
