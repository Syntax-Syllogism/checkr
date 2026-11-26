/**
 * Local checklist viewer fixture used by the optional development mock-data mode.
 */
const mockChecklistViewerData = {
  recordId: "001CKR000000001AAA",
  checklists: [
    {
      checklistInstanceId: "a02CKR000000001AAA",
      name: "Account Onboarding",
      ownerName: "CheckR Smoke Owner",
      isComplete: true,
      isOverdue: false,
      percentComplete: 100,
      dueDate: "2026-05-18",
      canEditItems: true,
      permissionMessage: null,
      items: [
        {
          checklistItemId: "a03CKR000000001AAA",
          label: "Confirm executive sponsor",
          required: true,
          completed: true,
          checkboxValue: true,
          explanation: "Sponsor confirmed in kickoff call.",
          explanationInputType: "Text",
          explanationPicklistValues: null,
          assigneeUserId: null,
          assigneeName: null,
          canEdit: true,
          isAdHoc: false,
          explanationRequired: true
        },
        {
          checklistItemId: "a03CKR000000002AAA",
          label: "Select billing profile",
          required: true,
          completed: true,
          checkboxValue: true,
          explanation: "Enterprise Billing",
          explanationInputType: "Picklist",
          explanationPicklistValues:
            "Standard Billing;Enterprise Billing;Partner Billing",
          assigneeUserId: null,
          assigneeName: null,
          canEdit: true,
          isAdHoc: false,
          explanationRequired: false
        },
        {
          checklistItemId: "a03CKR000000003AAA",
          label: "Capture kickoff notes",
          required: false,
          completed: false,
          checkboxValue: false,
          explanation: "",
          explanationInputType: "Text",
          explanationPicklistValues: null,
          assigneeUserId: null,
          assigneeName: null,
          canEdit: true,
          isAdHoc: false,
          explanationRequired: true
        },
        {
          checklistItemId: "a03CKR000000004AAA",
          label: "Capture VAT certificate",
          required: false,
          completed: false,
          checkboxValue: false,
          explanation: "",
          explanationInputType: "Text",
          explanationPicklistValues: null,
          assigneeUserId: null,
          assigneeName: null,
          canEdit: true,
          isAdHoc: true,
          explanationRequired: false
        }
      ]
    },
    {
      checklistInstanceId: "a02CKR000000002AAA",
      name: "Renewal Readiness",
      ownerName: "CheckR Smoke Owner",
      isComplete: false,
      isOverdue: false,
      percentComplete: 50,
      dueDate: "2026-05-08",
      canEditItems: true,
      permissionMessage: null,
      items: [
        {
          checklistItemId: "a03CKR000000005AAA",
          label: "Validate renewal amount",
          required: true,
          completed: true,
          checkboxValue: true,
          explanation: "",
          explanationInputType: "Text",
          explanationPicklistValues: null,
          assigneeUserId: null,
          assigneeName: null,
          canEdit: true,
          isAdHoc: false,
          explanationRequired: false
        },
        {
          checklistItemId: "a03CKR000000006AAA",
          label: "Choose renewal risk",
          required: true,
          completed: false,
          checkboxValue: false,
          explanation: "",
          explanationInputType: "Picklist",
          explanationPicklistValues: "Low Risk;Medium Risk;High Risk",
          assigneeUserId: null,
          assigneeName: null,
          canEdit: true,
          isAdHoc: false,
          explanationRequired: false
        },
        {
          checklistItemId: "a03CKR000000007AAA",
          label: "Confirm legal terms",
          required: false,
          completed: false,
          checkboxValue: false,
          explanation: "",
          explanationInputType: "Text",
          explanationPicklistValues: null,
          assigneeUserId: null,
          assigneeName: null,
          canEdit: true,
          isAdHoc: false,
          explanationRequired: true
        },
        {
          checklistItemId: "a03CKR000000008AAA",
          label: "Executive review required",
          required: false,
          completed: true,
          checkboxValue: true,
          explanation: "VP review scheduled.",
          explanationInputType: "Picklist",
          explanationPicklistValues: "Yes;No",
          assigneeUserId: null,
          assigneeName: null,
          canEdit: true,
          isAdHoc: true,
          explanationRequired: true
        }
      ]
    },
    {
      checklistInstanceId: "a02CKR000000003AAA",
      name: "Compliance Review",
      ownerName: "CheckR Smoke Owner",
      isComplete: false,
      isOverdue: false,
      percentComplete: 50,
      dueDate: "2026-05-12",
      canEditItems: false,
      permissionMessage:
        "You do not have permission to update checklist items for this checklist.",
      items: [
        {
          checklistItemId: "a03CKR000000009AAA",
          label: "Verify KYC documents",
          required: true,
          completed: true,
          checkboxValue: true,
          explanation: "",
          explanationInputType: "Text",
          explanationPicklistValues: null,
          assigneeUserId: null,
          assigneeName: null,
          canEdit: false,
          isAdHoc: false,
          explanationRequired: false
        },
        {
          checklistItemId: "a03CKR000000010AAA",
          label: "Sanctions screening outcome",
          required: true,
          completed: false,
          checkboxValue: true,
          explanation: "",
          explanationInputType: "Picklist",
          explanationPicklistValues: "Clear;Review Required",
          assigneeUserId: null,
          assigneeName: null,
          canEdit: false,
          isAdHoc: false,
          explanationRequired: true
        },
        {
          checklistItemId: "a03CKR000000011AAA",
          label: "Escalation noted",
          required: false,
          completed: false,
          checkboxValue: false,
          explanation: "",
          explanationInputType: "Text",
          explanationPicklistValues: null,
          assigneeUserId: null,
          assigneeName: null,
          canEdit: false,
          isAdHoc: false,
          explanationRequired: true
        }
      ]
    }
  ]
};

export default mockChecklistViewerData;
