import { createElement } from "lwc";
import PublishAction from "c/ckrPublishTemplateVersion";
import publishVersion from "@salesforce/apex/CKR_TemplateVersionPublishController.publishVersion";
const ShowToastEventName = "lightning__showtoast";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";

jest.mock(
  "@salesforce/apex/CKR_TemplateVersionPublishController.publishVersion",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
const flush = () => Promise.resolve();
describe("publish version action", () => {
  afterEach(() => {
    while (document.body.firstChild)
      document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });
  function mount() {
    const action = createElement("c-ckr-publish-template-version", {
      is: PublishAction
    });
    action.recordId = "version-id";
    document.body.appendChild(action);
    return action;
  }
  it("publishes once during concurrent invocations and refreshes", async () => {
    let finish;
    publishVersion.mockReturnValue(
      new Promise((resolve) => {
        finish = resolve;
      })
    );
    const action = mount();
    const toast = jest.fn();
    action.addEventListener(ShowToastEventName, toast);
    action.invoke();
    action.invoke();
    expect(publishVersion).toHaveBeenCalledTimes(1);
    expect(publishVersion).toHaveBeenCalledWith({
      templateVersionId: "version-id"
    });
    finish();
    await flush();
    await flush();
    expect(toast.mock.calls[0][0].detail.variant).toBe("success");
    expect(notifyRecordUpdateAvailable).toHaveBeenCalledWith([
      { recordId: "version-id" }
    ]);
  });
  it("shows server errors and allows retry", async () => {
    publishVersion.mockRejectedValue({
      body: { message: "Only Draft versions can be published." }
    });
    const action = mount();
    const toast = jest.fn();
    action.addEventListener(ShowToastEventName, toast);
    await action.invoke();
    expect(toast.mock.calls[0][0].detail.message).toBe(
      "Only Draft versions can be published."
    );
    await action.invoke();
    expect(publishVersion).toHaveBeenCalledTimes(2);
  });
});
