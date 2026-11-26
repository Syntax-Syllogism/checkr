import { LightningElement, api, wire } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";
import { CurrentPageReference } from "lightning/navigation";
import { RefreshEvent } from "lightning/refresh";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCreateContext from "@salesforce/apex/CKR_ChecklistCreateActionController.getCreateContext";
import createChecklistAction from "@salesforce/apex/CKR_ChecklistCreateActionController.createChecklistAction";

/**
 * Screen-action component for attaching a published checklist template to a record.
 */
export default class CkrChecklistCreateAction extends LightningElement {
  @api recordId;
  @api objectApiName;
  @api title = "CheckR Create Checklist";

  context = { templates: [] };
  isLoading = true;
  isSaving = false;
  pageRecordId;
  pageObjectApiName;
  selectedTemplateVersionId;
  dueDate;

  /**
   * Captures quick-action page context when recordId and objectApiName are not passed directly.
   *
   * @param {object} pageReference current Lightning page reference
   */
  @wire(CurrentPageReference)
  wiredPageReference(pageReference) {
    this.pageRecordId =
      pageReference?.state?.recordId || pageReference?.attributes?.recordId;
    this.pageObjectApiName =
      pageReference?.attributes?.objectApiName ||
      pageReference?.state?.objectApiName;
  }

  /**
   * Loads eligible checklist templates for the current record and preselects the only option.
   *
   * @param {object} response wire response from getCreateContext
   * @param {object} response.data create context returned by Apex
   * @param {object} response.error wire error returned by Apex
   */
  @wire(getCreateContext, {
    recordId: "$effectiveRecordId",
    objectApiName: "$effectiveObjectApiName"
  })
  wiredContext({ data, error }) {
    this.isLoading = false;

    if (data) {
      this.context = data;
      if (!this.selectedTemplateVersionId && data.templates?.length === 1) {
        this.selectedTemplateVersionId = data.templates[0].templateVersionId;
      }
      return;
    }

    if (error) {
      this.context = { templates: [] };
    }
  }

  /**
   * @returns {string} title shown in the quick-action panel
   */
  get panelTitle() {
    return this.title;
  }

  /**
   * @returns {string|null} record id resolved from component API or page context
   */
  get effectiveRecordId() {
    return this.recordId || this.pageRecordId || null;
  }

  /**
   * @returns {string|null} object API name resolved from component API or page context
   */
  get effectiveObjectApiName() {
    return this.objectApiName || this.pageObjectApiName || null;
  }

  /**
   * @returns {boolean} true when at least one template can be selected
   */
  get hasTemplates() {
    return this.templateCount > 0;
  }

  /**
   * @returns {number} count of eligible template options
   */
  get templateCount() {
    return this.context?.templates?.length || 0;
  }

  /**
   * @returns {Array<object>} combobox options for eligible template versions
   */
  get templateOptions() {
    return (this.context?.templates || []).map((template) => ({
      label: template.versionNumber
        ? `${template.name} (v${template.versionNumber})`
        : template.name,
      value: template.templateVersionId,
      description: template.description
    }));
  }

  /**
   * @returns {boolean} true when the create action cannot be submitted
   */
  get createDisabled() {
    return (
      this.isSaving ||
      !this.selectedTemplateVersionId ||
      !this.effectiveRecordId ||
      !this.effectiveObjectApiName
    );
  }

  /**
   * Stores the selected template version from the template combobox.
   *
   * @param {CustomEvent} event combobox change event
   */
  handleTemplateChange(event) {
    this.selectedTemplateVersionId = event.detail.value;
  }

  /**
   * Stores the optional due date from the date input.
   *
   * @param {CustomEvent} event date input change event
   */
  handleDueDateChange(event) {
    this.dueDate = event.detail.value;
  }

  /**
   * Creates the checklist instance, shows the result toast, refreshes the page, and closes the action.
   *
   * @returns {Promise<void>}
   */
  async handleCreate() {
    const selectedTemplate = (this.context.templates || []).find(
      (template) =>
        template.templateVersionId === this.selectedTemplateVersionId
    );
    if (!selectedTemplate) {
      return;
    }

    this.isSaving = true;

    try {
      const result = await createChecklistAction({
        request: {
          templateId: selectedTemplate.templateId,
          templateVersionId: selectedTemplate.templateVersionId,
          parentRecordId: this.effectiveRecordId,
          parentObjectApiName: this.effectiveObjectApiName,
          dueDate: this.dueDate || null
        }
      });

      if (!result?.success) {
        throw new Error(
          (result?.messages || []).join(" ") || "Checklist creation failed."
        );
      }

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Checklist Created",
          message: "The checklist was created successfully.",
          variant: "success"
        })
      );
      this.dispatchEvent(new RefreshEvent());
      this.dispatchEvent(new CloseActionScreenEvent());
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Checklist Creation Failed",
          message:
            error?.body?.message ||
            error?.message ||
            "An unexpected error occurred.",
          variant: "error"
        })
      );
    } finally {
      this.isSaving = false;
    }
  }

  /**
   * Closes the screen action without creating a checklist.
   */
  handleCancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }
}
