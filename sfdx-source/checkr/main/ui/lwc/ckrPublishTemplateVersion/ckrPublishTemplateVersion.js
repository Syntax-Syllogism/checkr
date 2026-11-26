import { LightningElement, api } from "lwc";
import publishVersion from "@salesforce/apex/CKR_TemplateVersionPublishController.publishVersion";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";

export default class CkrPublishTemplateVersion extends LightningElement {
  @api recordId;
  publishing = false;

  @api async invoke() {
    if (this.publishing) return;
    this.publishing = true;
    try {
      await publishVersion({ templateVersionId: this.recordId });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Version published",
          message: "New checklists will use this version.",
          variant: "success"
        })
      );
      await notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Cannot publish version",
          message: error.body?.message || error.message || "Publishing failed.",
          variant: "error"
        })
      );
    } finally {
      this.publishing = false;
    }
  }
}
