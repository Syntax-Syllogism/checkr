import { createElement } from "lwc";
import CkrChecklistCreateAction from "c/ckrChecklistCreateAction";
import getCreateContext from "@salesforce/apex/CKR_ChecklistCreateActionController.getCreateContext";
import createChecklistAction from "@salesforce/apex/CKR_ChecklistCreateActionController.createChecklistAction";

jest.mock(
  "@salesforce/apex/CKR_ChecklistCreateActionController.getCreateContext",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return {
      default: createApexTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/CKR_ChecklistCreateActionController.createChecklistAction",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

/**
 * Allows pending wire and imperative Apex promises to settle.
 *
 * @returns {Promise<void>}
 */
const flushPromises = () => Promise.resolve();

/**
 * Renders the create action with Account record context.
 *
 * @returns {HTMLElement} rendered component element
 */
function renderCreateAction() {
  const element = createElement("c-ckr-checklist-create-action", {
    is: CkrChecklistCreateAction
  });
  element.recordId = "001000000000001AAA";
  element.objectApiName = "Account";
  document.body.appendChild(element);
  return element;
}

describe("c-ckr-checklist-create-action", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders empty template message when no templates are returned", async () => {
    const element = renderCreateAction();

    getCreateContext.emit({
      recordId: "001000000000001AAA",
      objectApiName: "Account",
      templates: []
    });

    await Promise.resolve();

    expect(element.shadowRoot.textContent).toContain(
      "No eligible templates are available yet."
    );
  });

  it("creates a checklist from the selected template", async () => {
    createChecklistAction.mockResolvedValue({
      success: true,
      checklistInstanceId: "a02000000000001AAA",
      messages: ["Checklist instance created successfully."]
    });

    const element = renderCreateAction();

    getCreateContext.emit({
      recordId: "001000000000001AAA",
      objectApiName: "Account",
      templates: [
        {
          templateId: "a00000000000001AAA",
          templateVersionId: "a01000000000001AAA",
          name: "Account Launch",
          versionNumber: 1
        }
      ]
    });

    await flushPromises();

    const combobox = element.shadowRoot.querySelector("lightning-combobox");
    combobox.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "a01000000000001AAA" }
      })
    );

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    buttons[1].click();

    await flushPromises();

    expect(createChecklistAction).toHaveBeenCalled();
    expect(createChecklistAction.mock.calls[0][0].request.templateId).toBe(
      "a00000000000001AAA"
    );
    expect(
      createChecklistAction.mock.calls[0][0].request.templateVersionId
    ).toBe("a01000000000001AAA");
  });

  it("clears templates when the create context wire fails", async () => {
    const element = renderCreateAction();

    getCreateContext.error({
      body: { message: "Unable to load templates." }
    });

    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "No eligible templates are available yet."
    );
    expect(element.shadowRoot.querySelector("lightning-combobox")).toBeNull();
  });

  it("shows an error toast when creation returns a failure result", async () => {
    createChecklistAction.mockResolvedValue({
      success: false,
      messages: ["Duplicate checklist."]
    });
    const element = renderCreateAction();
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);

    getCreateContext.emit({
      recordId: "001000000000001AAA",
      objectApiName: "Account",
      templates: [
        {
          templateId: "a00000000000001AAA",
          templateVersionId: "a01000000000001AAA",
          name: "Account Launch",
          versionNumber: 1
        }
      ]
    });

    await flushPromises();

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    buttons[1].click();

    await flushPromises();

    expect(toastHandler).toHaveBeenCalled();
    expect(toastHandler.mock.calls[0][0].detail.variant).toBe("error");
    expect(toastHandler.mock.calls[0][0].detail.message).toBe(
      "Duplicate checklist."
    );
  });

  it("dispatches close when cancel is clicked", async () => {
    const element = renderCreateAction();
    const closeHandler = jest.fn();
    element.addEventListener("closeactionscreenevent", closeHandler);

    getCreateContext.emit({
      recordId: "001000000000001AAA",
      objectApiName: "Account",
      templates: []
    });

    await flushPromises();

    const buttons = element.shadowRoot.querySelectorAll("lightning-button");
    buttons[0].click();

    expect(closeHandler).toHaveBeenCalled();
  });
});
