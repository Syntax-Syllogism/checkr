const { test, expect } = require("@playwright/test");
const {
  openRecordPage,
  requireEnv,
  maybeOpenAccordionSection,
  createSafeTestLabel,
  findChecklistViewer
} = require("./support/salesforce");

test.describe("checklist viewer", () => {
  test("renders a checklist and allows inline updates", async ({ page }) => {
    const recordId = requireEnv("CKR_VIEWER_RECORD_ID");
    const objectApiName =
      process.env.CKR_VIEWER_RECORD_OBJECT_API_NAME || "Account";
    const checklistName =
      process.env.CKR_VIEWER_CHECKLIST_NAME || "Account Onboarding";
    const explanationItemLabel =
      process.env.CKR_VIEWER_EXPLANATION_ITEM_LABEL ||
      "Confirm executive sponsor";
    const newAdHocLabel = createSafeTestLabel("Playwright ad hoc item");
    const updatedExplanation = createSafeTestLabel("Updated by Playwright at");

    await openRecordPage(page, objectApiName, recordId);

    const viewer = await findChecklistViewer(page, checklistName);
    await expect(viewer).toBeVisible();
    await expect(
      viewer.getByText("CheckR Checklist Viewer").first()
    ).toBeVisible();
    await maybeOpenAccordionSection(viewer, checklistName);

    const checklistButton = viewer.getByRole("button", {
      name: new RegExp(`${checklistName} \\(`)
    });
    await expect(checklistButton.first()).toBeVisible();
    await expect(
      viewer
        .getByText(
          new RegExp(
            `^${explanationItemLabel.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`
          )
        )
        .first()
    ).toBeVisible();

    const itemRow = viewer
      .locator(".checklist-item")
      .filter({ hasText: explanationItemLabel })
      .first();
    await expect(itemRow).toBeVisible();

    const explanationInput = itemRow.getByRole("textbox", {
      name: "Explanation"
    });
    await explanationInput.fill(updatedExplanation);
    await explanationInput.blur();

    await expect(viewer.getByText("Saving changes...")).toHaveCount(0);
    await expect(explanationInput).toHaveValue(updatedExplanation);

    await viewer.getByLabel("New Item Label").fill(newAdHocLabel);
    await viewer.getByRole("button", { name: "Add Item" }).click();

    await expect(
      viewer.getByText(newAdHocLabel, { exact: true })
    ).toBeVisible();
  });
});
