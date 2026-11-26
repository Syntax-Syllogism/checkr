import { createElement } from "lwc";
import CkrChecklistViewer from "c/ckrChecklistViewer";
import getRecordChecklists from "@salesforce/apex/CKR_ChecklistViewerController.getRecordChecklists";
import updateChecklistItem from "@salesforce/apex/CKR_ChecklistViewerController.updateChecklistItem";
import addAdHocItem from "@salesforce/apex/CKR_ChecklistViewerController.addAdHocItem";
import removeAdHocItem from "@salesforce/apex/CKR_ChecklistViewerController.removeAdHocItem";

jest.mock(
  "@salesforce/apex/CKR_ChecklistViewerController.getRecordChecklists",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return {
      default: createApexTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/CKR_ChecklistViewerController.updateChecklistItem",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/CKR_ChecklistViewerController.addAdHocItem",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/CKR_ChecklistViewerController.removeAdHocItem",
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
 * Renders the viewer with live Apex wire data.
 *
 * @param {object} payload wire payload emitted by getRecordChecklists
 * @returns {HTMLElement} rendered component element
 */
function renderViewer(payload) {
  const element = createElement("c-ckr-checklist-viewer", {
    is: CkrChecklistViewer
  });
  element.recordId = "001000000000001AAA";
  document.body.appendChild(element);
  getRecordChecklists.emit(payload);
  return element;
}

/**
 * Renders the viewer using local mock checklist data.
 *
 * @param {object} options render options
 * @param {boolean} options.showToggle whether the mock-data toggle is visible
 * @returns {HTMLElement} rendered component element
 */
function renderMockViewer({ showToggle = false } = {}) {
  const element = createElement("c-ckr-checklist-viewer", {
    is: CkrChecklistViewer
  });
  element.recordId = "001CKR000000001AAA";
  element.mockDataEnabled = true;
  element.showMockDataToggle = showToggle;
  document.body.appendChild(element);
  return element;
}

/**
 * Builds a checklist test fixture.
 *
 * @param {object} overrides values to merge into the default checklist
 * @returns {object} checklist fixture
 */
function checklist(overrides = {}) {
  return {
    checklistInstanceId: "a02000000000001AAA",
    name: "Account Launch",
    ownerName: "Launch Queue",
    percentComplete: 0,
    isComplete: false,
    canEditItems: true,
    items: [],
    ...overrides
  };
}

/**
 * Builds a checklist item test fixture.
 *
 * @param {object} overrides values to merge into the default item
 * @returns {object} checklist item fixture
 */
function item(overrides = {}) {
  return {
    checklistItemId: "a03000000000001AAA",
    label: "Confirm billing contact",
    required: true,
    canEdit: true,
    completed: false,
    checkboxValue: false,
    explanation: "",
    explanationInputType: "Text",
    explanationPicklistValues: null,
    assigneeUserId: null,
    assigneeName: null,
    ...overrides
  };
}

/**
 * Finds a lightning-button in the component shadow DOM by label.
 *
 * @param {HTMLElement} element rendered component element
 * @param {string} label button label to match
 * @returns {HTMLElement|undefined} matching button, if present
 */
function findButtonByLabel(element, label) {
  return Array.from(
    element.shadowRoot.querySelectorAll("lightning-button")
  ).find((button) => button.label === label);
}

/**
 * Opens the inline ad hoc item composer.
 *
 * @param {HTMLElement} element rendered component element
 * @returns {Promise<void>}
 */
async function openAdHocComposer(element) {
  element.shadowRoot.querySelector(".checklist-add-row").click();
  await flushPromises();
}

describe("c-ckr-checklist-viewer", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders empty state when no checklists are returned", async () => {
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: []
    });

    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "No checklists are attached to this record yet."
    );
  });

  it("renders a load error when the checklist wire fails", async () => {
    const element = createElement("c-ckr-checklist-viewer", {
      is: CkrChecklistViewer
    });
    element.recordId = "001000000000001AAA";
    document.body.appendChild(element);

    getRecordChecklists.error({
      body: { message: "Unable to load test checklists." }
    });

    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "Unable to load checklists for this record."
    );
  });

  it("renders checklist items and updates a checkbox item", async () => {
    updateChecklistItem.mockResolvedValue({});
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [item()]
        })
      ]
    });

    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Account Launch");
    expect(findButtonByLabel(element, "Confirm billing contact")).toBeTruthy();
    expect(element.shadowRoot.textContent).toContain("0/1 required");
    expect(element.shadowRoot.textContent).toContain("0/1 total");
    expect(element.shadowRoot.textContent).not.toContain("Required Complete");
    expect(element.shadowRoot.textContent).not.toContain("Total Complete");
    expect(element.shadowRoot.textContent).not.toContain("Owner:");
    expect(element.shadowRoot.textContent).not.toContain("Launch Queue");
    expect(element.shadowRoot.querySelector("lightning-record-picker")).toBe(
      null
    );

    const checkbox = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input")
    ).find((input) => input.label === "Complete");
    checkbox.checked = true;
    checkbox.dispatchEvent(
      new CustomEvent("change", {
        detail: { checked: true },
        target: {
          dataset: { itemId: "a03000000000001AAA" },
          checked: true
        }
      })
    );

    await flushPromises();

    expect(updateChecklistItem).toHaveBeenCalled();
    expect(updateChecklistItem.mock.calls[0][0].request.checklistItemId).toBe(
      "a03000000000001AAA"
    );
    expect(updateChecklistItem.mock.calls[0][0].request.checkboxValue).toBe(
      true
    );
  });

  it("counts checked items and shows status icons from the visible checkbox value", async () => {
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [
            item({
              checklistItemId: "a03000000000001AAA",
              label: "Required checked",
              required: true,
              completed: false,
              checkboxValue: true
            }),
            item({
              checklistItemId: "a03000000000002AAA",
              label: "Optional checked",
              required: false,
              completed: false,
              checkboxValue: true
            })
          ]
        })
      ]
    });

    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("1/1 required");
    expect(element.shadowRoot.textContent).toContain("2/2 total");
    const itemStatusIcons = Array.from(
      element.shadowRoot.querySelectorAll(
        ".checklist-item__status lightning-icon"
      )
    ).filter((icon) => icon.iconName === "utility:success");
    expect(itemStatusIcons).toHaveLength(2);
  });

  it("renders local smoke-seed mock data without calling Apex", async () => {
    const element = renderMockViewer({ showToggle: true });

    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Mock Data");
    expect(element.shadowRoot.textContent).toContain("Account Onboarding");
    expect(
      findButtonByLabel(element, "Confirm executive sponsor")
    ).toBeTruthy();
    expect(findButtonByLabel(element, "Select billing profile")).toBeTruthy();
    expect(updateChecklistItem).not.toHaveBeenCalled();
  });

  it("switches from live data to local mock data with the dev toggle", async () => {
    const element = createElement("c-ckr-checklist-viewer", {
      is: CkrChecklistViewer
    });
    element.recordId = "001000000000001AAA";
    element.showMockDataToggle = true;
    document.body.appendChild(element);

    getRecordChecklists.emit({
      recordId: "001000000000001AAA",
      checklists: []
    });

    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Live Data");
    expect(element.shadowRoot.textContent).toContain(
      "No checklists are attached to this record yet."
    );

    const toggle = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input")
    ).find((input) => input.label === "Use Mock Data");
    toggle.checked = true;
    toggle.dispatchEvent(
      new CustomEvent("change", {
        target: { checked: true }
      })
    );

    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Mock Data");
    expect(element.shadowRoot.textContent).toContain("Account Onboarding");
  });

  it("collapses and expands a checklist from the custom header", async () => {
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [item()]
        })
      ]
    });

    await flushPromises();

    const sectionHeader = element.shadowRoot.querySelector(
      ".checklist-section__header"
    );
    expect(sectionHeader.getAttribute("aria-expanded")).toBe("true");
    expect(findButtonByLabel(element, "Confirm billing contact")).toBeTruthy();

    sectionHeader.click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(".checklist-section__header")
    ).toBeTruthy();
    expect(
      element.shadowRoot
        .querySelector(".checklist-section__header")
        .getAttribute("aria-expanded")
    ).toBe("false");
    expect(findButtonByLabel(element, "Confirm billing contact")).toBeFalsy();

    element.shadowRoot.querySelector(".checklist-section__header").click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(".checklist-section__header")
    ).toBeTruthy();
    expect(
      element.shadowRoot
        .querySelector(".checklist-section__header")
        .getAttribute("aria-expanded")
    ).toBe("true");
    expect(findButtonByLabel(element, "Confirm billing contact")).toBeTruthy();
  });

  it("opens item details from the task name using one footer action row", async () => {
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [item()]
        })
      ]
    });

    await flushPromises();

    const taskButton = findButtonByLabel(element, "Confirm billing contact");
    taskButton.click();

    await flushPromises();

    const panel = element.shadowRoot.querySelector(
      "lightning-quick-action-panel"
    );
    const editForm = element.shadowRoot.querySelector(
      "lightning-record-edit-form"
    );
    const inputFields = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input-field")
    );
    expect(panel.header).toBe("Confirm billing contact");
    expect(editForm.recordId).toBe("a03000000000001AAA");
    expect(editForm.objectApiName).toBe("CKR_ChecklistInstanceItem__c");
    expect(element.shadowRoot.querySelector("lightning-record-form")).toBe(
      null
    );
    expect(inputFields.map((field) => field.fieldName)).toEqual([
      "CKR_Label__c",
      "CKR_Required__c",
      "CKR_CheckboxValue__c",
      "CKR_AssigneeUser__c",
      "CKR_Completed__c"
    ]);

    const closeButton = findButtonByLabel(element, "Close");
    const saveButton = findButtonByLabel(element, "Save");
    expect(saveButton).toBeTruthy();
    closeButton.click();

    await flushPromises();

    expect(
      element.shadowRoot.querySelector("lightning-quick-action-panel")
    ).toBe(null);
  });

  it("uses a single-line text explanation input", async () => {
    updateChecklistItem.mockResolvedValue({});
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [
            item({
              label: "Capture kickoff notes",
              required: false
            })
          ]
        })
      ]
    });

    await flushPromises();

    const explanationInput = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input")
    ).find((input) => input.label === "Explanation");
    expect(explanationInput).toBeTruthy();
    expect(
      Array.from(
        element.shadowRoot.querySelectorAll("lightning-combobox")
      ).some((combobox) => combobox.label === "Explanation")
    ).toBe(false);

    explanationInput.value = "Notes taken during Monday sync.";
    explanationInput.dispatchEvent(
      new CustomEvent("blur", {
        target: {
          dataset: { itemId: "a03000000000001AAA" },
          value: "Notes taken during Monday sync."
        }
      })
    );

    await flushPromises();

    expect(updateChecklistItem).toHaveBeenCalled();
    expect(updateChecklistItem.mock.calls[0][0].request.explanation).toBe(
      "Notes taken during Monday sync."
    );
  });

  it("renders picklist explanation options", async () => {
    updateChecklistItem.mockResolvedValue({});
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [
            item({
              label: "Choose onboarding path",
              explanationInputType: "Picklist",
              explanationPicklistValues:
                "First Option,Second Option\nThird Option"
            })
          ]
        })
      ]
    });

    await flushPromises();

    const explanationCombobox = Array.from(
      element.shadowRoot.querySelectorAll("lightning-combobox")
    ).find((combobox) => combobox.label === "Explanation");
    expect(explanationCombobox.options).toEqual([
      { label: "First Option", value: "First Option" },
      { label: "Second Option", value: "Second Option" },
      { label: "Third Option", value: "Third Option" }
    ]);

    explanationCombobox.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "Second Option" },
        target: {
          dataset: { itemId: "a03000000000001AAA" }
        }
      })
    );

    await flushPromises();

    expect(updateChecklistItem.mock.calls[0][0].request.explanation).toBe(
      "Second Option"
    );
  });

  it("adds an item inline without item type parameters", async () => {
    addAdHocItem.mockResolvedValue({});
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [checklist()]
    });

    await flushPromises();
    await openAdHocComposer(element);

    const newLabelInput = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input")
    ).find((input) => input.label === "Item Label");
    expect(newLabelInput).toBeTruthy();
    newLabelInput.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "Capture hallway note" },
        target: {
          dataset: {
            checklistId: "a02000000000001AAA",
            fieldName: "label"
          }
        }
      })
    );

    await flushPromises();

    const button = findButtonByLabel(element, "Add Item");
    button.click();

    await flushPromises();

    expect(addAdHocItem).toHaveBeenCalled();
    expect(addAdHocItem.mock.calls[0][0].request).toMatchObject({
      checklistInstanceId: "a02000000000001AAA",
      label: "Capture hallway note",
      explanationInputType: "Text",
      explanationRequired: false,
      assigneeUserId: null
    });
    expect(removeAdHocItem).not.toHaveBeenCalled();
  });

  it("shows an error toast when adding an item without a label", async () => {
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [checklist()]
    });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);

    await flushPromises();
    await openAdHocComposer(element);

    const button = findButtonByLabel(element, "Add Item");
    button.click();

    await flushPromises();

    expect(addAdHocItem).not.toHaveBeenCalled();
    expect(toastHandler).toHaveBeenCalled();
    expect(toastHandler.mock.calls[0][0].detail.title).toBe("Item Required");
  });

  it("shows an error toast when adding an item fails", async () => {
    addAdHocItem.mockRejectedValue({
      body: { message: "Server refused the item." }
    });
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [checklist()]
    });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);

    await flushPromises();
    await openAdHocComposer(element);

    const newLabelInput = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input")
    ).find((input) => input.label === "Item Label");
    newLabelInput.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "Capture exception path" },
        target: {
          dataset: {
            checklistId: "a02000000000001AAA",
            fieldName: "label"
          }
        }
      })
    );

    await flushPromises();

    const button = findButtonByLabel(element, "Add Item");
    button.click();

    await flushPromises();

    expect(toastHandler).toHaveBeenCalled();
    expect(toastHandler.mock.calls[0][0].detail.title).toBe("Add Item Failed");
    expect(toastHandler.mock.calls[0][0].detail.message).toBe(
      "Server refused the item."
    );
  });

  it("removes an editable ad hoc item", async () => {
    removeAdHocItem.mockResolvedValue({});
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [
            item({
              checklistItemId: "a03000000000009AAA",
              label: "Remove this ad hoc item",
              required: false,
              isAdHoc: true
            })
          ]
        })
      ]
    });

    await flushPromises();

    const button = Array.from(
      element.shadowRoot.querySelectorAll("lightning-button-icon")
    ).find((candidate) => candidate.alternativeText === "Delete item");
    button.click();

    await flushPromises();

    expect(removeAdHocItem).toHaveBeenCalledWith({
      checklistItemId: "a03000000000009AAA"
    });
  });

  it("shows an error toast when removing an ad hoc item fails", async () => {
    removeAdHocItem.mockRejectedValue(new Error("Remove failed."));
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [
            item({
              checklistItemId: "a03000000000009AAA",
              label: "Remove failure path",
              required: false,
              isAdHoc: true
            })
          ]
        })
      ]
    });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);

    await flushPromises();

    const button = Array.from(
      element.shadowRoot.querySelectorAll("lightning-button-icon")
    ).find((candidate) => candidate.alternativeText === "Delete item");
    button.click();

    await flushPromises();

    expect(toastHandler).toHaveBeenCalled();
    expect(toastHandler.mock.calls[0][0].detail.title).toBe(
      "Remove Item Failed"
    );
    expect(toastHandler.mock.calls[0][0].detail.message).toBe("Remove failed.");
  });

  it("shows an error toast when saving an item fails", async () => {
    updateChecklistItem.mockRejectedValue(new Error("Save failed."));
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [item()]
        })
      ]
    });
    const toastHandler = jest.fn();
    element.addEventListener("lightning__showtoast", toastHandler);

    await flushPromises();

    const checkbox = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input")
    ).find((input) => input.label === "Complete");
    checkbox.checked = true;
    checkbox.dispatchEvent(
      new CustomEvent("change", {
        detail: { checked: true },
        target: {
          dataset: { itemId: "a03000000000001AAA" },
          checked: true
        }
      })
    );

    await flushPromises();

    expect(toastHandler).toHaveBeenCalled();
    expect(toastHandler.mock.calls[0][0].detail.title).toBe(
      "Checklist Update Failed"
    );
    expect(toastHandler.mock.calls[0][0].detail.message).toBe("Save failed.");
  });

  it("adds and removes picklist explanation options as pills", async () => {
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [checklist()]
    });

    await flushPromises();
    await openAdHocComposer(element);

    const explanationTypeCombobox = Array.from(
      element.shadowRoot.querySelectorAll("lightning-combobox")
    ).find((combobox) => combobox.label === "Explanation Type");
    explanationTypeCombobox.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "Picklist" },
        target: {
          dataset: {
            checklistId: "a02000000000001AAA",
            fieldName: "explanationInputType"
          }
        }
      })
    );

    await flushPromises();

    const optionInput = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input")
    ).find((input) => input.label === "Picklist Option");
    optionInput.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "Escalated" },
        target: {
          dataset: {
            checklistId: "a02000000000001AAA",
            fieldName: "picklistOptionDraft"
          }
        }
      })
    );

    await flushPromises();

    const addOptionButton = Array.from(
      element.shadowRoot.querySelectorAll("lightning-button-icon")
    ).find((button) => button.alternativeText === "Add Picklist Option");
    addOptionButton.click();

    await flushPromises();

    const pill = element.shadowRoot.querySelector("lightning-pill");
    expect(pill.label).toBe("Escalated");

    pill.dispatchEvent(new CustomEvent("remove"));

    await flushPromises();

    expect(element.shadowRoot.querySelector("lightning-pill")).toBe(null);

    optionInput.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "Escalated" },
        target: {
          dataset: {
            checklistId: "a02000000000001AAA",
            fieldName: "picklistOptionDraft"
          }
        }
      })
    );
    addOptionButton.click();

    await flushPromises();

    const saveButton = findButtonByLabel(element, "Add Item");
    const newLabelInput = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input")
    ).find((input) => input.label === "Item Label");
    newLabelInput.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "Choose escalation path" },
        target: {
          dataset: {
            checklistId: "a02000000000001AAA",
            fieldName: "label"
          }
        }
      })
    );
    saveButton.click();

    await flushPromises();

    expect(
      addAdHocItem.mock.calls[0][0].request.explanationPicklistValues
    ).toBe("Escalated");
  });

  it("renders ad hoc items like standard checkbox items", async () => {
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [
            item({
              checklistItemId: "a03000000000009AAA",
              label: "Choose onboarding path",
              required: false,
              isAdHoc: true,
              explanationRequired: true,
              explanationInputType: "Picklist",
              explanationPicklistValues:
                "First Option,Second Option\nThird Option"
            })
          ]
        })
      ]
    });

    await flushPromises();

    expect(findButtonByLabel(element, "Choose onboarding path")).toBeTruthy();

    const inputs = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input")
    );
    expect(inputs.some((input) => input.label === "Item Label")).toBe(false);

    const button = Array.from(
      element.shadowRoot.querySelectorAll("lightning-button-icon")
    ).find((candidate) => candidate.alternativeText === "Delete item");
    expect(button).toBeTruthy();
    expect(button.disabled).toBe(false);
    expect(
      Array.from(
        element.shadowRoot.querySelectorAll("lightning-textarea")
      ).some((textarea) => textarea.label === "Explanation Picklist Values")
    ).toBe(false);
    expect(element.shadowRoot.textContent).toContain("OPTIONAL");
    expect(element.shadowRoot.textContent).not.toContain("REQUIRED");
  });

  it("renders read-only state when checklist items are not editable", async () => {
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          canEditItems: false,
          permissionMessage:
            "You do not have permission to update checklist items for this checklist.",
          items: [
            item({
              canEdit: false
            })
          ]
        })
      ]
    });

    await flushPromises();

    expect(element.shadowRoot.textContent).toContain(
      "You do not have permission to update checklist items for this checklist."
    );

    const checkbox = Array.from(
      element.shadowRoot.querySelectorAll("lightning-input")
    ).find((input) => input.label === "Complete");
    expect(checkbox.disabled).toBe(true);

    checkbox.dispatchEvent(
      new CustomEvent("change", {
        detail: { checked: true },
        target: {
          dataset: { itemId: "a03000000000001AAA" },
          checked: true
        }
      })
    );

    await flushPromises();

    expect(updateChecklistItem).not.toHaveBeenCalled();
  });

  it("shows disabled delete shade for standard template items", async () => {
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          items: [
            item({
              checklistItemId: "a03000000000001AAA",
              label: "Template item",
              isAdHoc: false
            })
          ]
        })
      ]
    });

    await flushPromises();

    const shade = element.shadowRoot.querySelector(
      ".checklist-item__delete-shade_disabled"
    );
    const button = Array.from(
      element.shadowRoot.querySelectorAll("lightning-button-icon")
    ).find(
      (candidate) =>
        candidate.alternativeText === "Delete is disabled on this item"
    );

    expect(shade).toBeTruthy();
    expect(button).toBeTruthy();
    expect(button.disabled).toBe(true);
  });

  it("shows disabled delete shade for read-only ad hoc items", async () => {
    const element = renderViewer({
      recordId: "001000000000001AAA",
      checklists: [
        checklist({
          canEditItems: false,
          permissionMessage:
            "You do not have permission to update checklist items for this checklist.",
          items: [
            item({
              checklistItemId: "a03000000000009AAA",
              label: "Read-only ad hoc item",
              canEdit: false,
              isAdHoc: true
            })
          ]
        })
      ]
    });

    await flushPromises();

    const shade = element.shadowRoot.querySelector(
      ".checklist-item__delete-shade_disabled"
    );
    const button = Array.from(
      element.shadowRoot.querySelectorAll("lightning-button-icon")
    ).find(
      (candidate) =>
        candidate.alternativeText === "Delete is disabled on this item"
    );

    expect(shade).toBeTruthy();
    expect(shade.title).toBe("Delete is disabled on this item");
    expect(button).toBeTruthy();
    expect(button.disabled).toBe(true);
  });
});
