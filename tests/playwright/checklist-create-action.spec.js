const { test, expect } = require("@playwright/test");
const {
  openRecordPage,
  openRecordPageFromApp,
  requireEnv,
  maybeCloseToast,
  findChecklistViewer
} = require("./support/salesforce");

test.describe("checklist create action", () => {
  test("creates a checklist from a published template", async ({ page }) => {
    const recordId = requireEnv("CKR_CREATE_RECORD_ID");
    const objectApiName =
      process.env.CKR_CREATE_RECORD_OBJECT_API_NAME || "Account";
    const quickActionLabel =
      process.env.CKR_CREATE_ACTION_LABEL || "New Checklist";
    const templateLabel =
      process.env.CKR_CREATE_TEMPLATE_LABEL || "Account Onboarding (v1)";
    const dueDate = process.env.CKR_CREATE_DUE_DATE || "2099-12-31";

    await openRecordPage(page, objectApiName, recordId);

    await openCreateChecklistAction(
      page,
      objectApiName,
      recordId,
      quickActionLabel
    );

    const modalTitle = page.getByText("CheckR Create Checklist");
    await expect(modalTitle).toBeVisible({ timeout: 45_000 });
    await expect(page.locator("lightning-spinner")).toBeHidden({
      timeout: 45_000
    });
    const createDialog = page.getByRole("dialog").first();
    await expect(createDialog).toBeVisible();

    const templateCombobox = page.getByRole("combobox", {
      name: "Checklist Template"
    });
    await selectComboboxOption(page, templateCombobox, templateLabel);
    await page.getByLabel("Due Date").fill(dueDate);
    await page.getByRole("button", { name: "Create Checklist" }).click();

    await expect(createDialog).toBeHidden({ timeout: 45_000 });
    await maybeCloseToast(page);

    await openRecordPageFromApp(page, objectApiName, recordId);

    const checklistName = templateLabel.replace(/\s+\(v\d+\)$/, "");
    const viewer = await findChecklistViewer(page, checklistName);
    await expect(
      viewer.getByRole("button", { name: new RegExp(`${checklistName} \\(`) })
    ).toBeVisible();
  });
});

async function selectComboboxOption(page, comboboxLocator, optionLabel) {
  await comboboxLocator.click();

  const option = page.getByRole("option", { name: optionLabel });
  try {
    await option.click({ timeout: 1_500 });
    return;
  } catch (_error) {
    await option.evaluate((element) => element.click());
  }
}

async function openCreateChecklistAction(
  page,
  objectApiName,
  recordId,
  quickActionLabel
) {
  const quickActionButton = page.getByRole("button", {
    name: quickActionLabel
  });
  if (await quickActionButton.count()) {
    await expect(quickActionButton.first()).toBeVisible({ timeout: 30_000 });
    await quickActionButton.first().click();
    return;
  }

  const showMoreActionsButton = page.getByRole("button", {
    name: "Show more actions"
  });
  if (await showMoreActionsButton.count()) {
    await showMoreActionsButton.first().click();
    const overflowAction = page.getByRole("menuitem", {
      name: quickActionLabel
    });
    if (await overflowAction.count()) {
      await expect(overflowAction.first()).toBeVisible({ timeout: 30_000 });
      await overflowAction.first().click();
      return;
    }
  }

  const currentUrl = new URL(page.url());
  const backgroundContext = currentUrl.pathname + currentUrl.search;
  const params = new URLSearchParams({
    objectApiName,
    context: "RECORD_DETAIL",
    recordId,
    backgroundContext
  });
  await page.goto(
    `${currentUrl.origin}/lightning/action/quick/${objectApiName}.CKR_New_Checklist?${params}`,
    { waitUntil: "domcontentloaded" }
  );
}
