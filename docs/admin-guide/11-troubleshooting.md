# Troubleshooting

## Users cannot save a record

Follow the [gate-blocking-saves runbook](../runbooks/gate-blocking-saves.md).

## A gate never fires

| Cause                                                                                           | Fix                                                                                                       |
| ----------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| The object has no trigger shim.                                                                 | A developer deploys one; see [Enabling an object](03-enabling-an-object.md#2-the-trigger-shim).           |
| The save was an insert.                                                                         | Expected: inserts are not gated. See [Gate rules](05-gate-rules.md#what-is-not-gated).                    |
| The version is still Draft and the record has no checklist.                                     | Publish it.                                                                                               |
| The rule is inactive, or the field API name is misspelled.                                      | Fix it in a new Draft version and publish.                                                                |
| `SpecificFieldValueChange` with a label instead of the API value.                               | Use the stored API value. See [Gate rules](05-gate-rules.md#fields).                                      |
| The record's checklist is from an older version that has no such rule.                          | Expected. See [Publishing](06-publishing-and-new-versions.md#what-happens-to-existing-records).           |
| The user is a System Administrator in an org where the install's profile grant was not removed. | Remove it; see [Installation](../installation.md#remove-the-admin-profiles-bypass-and-audit-maintenance). |
| The user or integration has bypass.                                                             | Check for a recent Gate Bypass Event, `CKR_GateBypass` assignments, and CheckR Settings rows.             |

## A retired template still blocks saves

Unchecking Active only hides a template from **New Checklist**. Publish a
version with no gate rules; see
[Retire a template](06-publishing-and-new-versions.md#retire-a-template).

## The checklist is not on the record page

- The record page has no `ckrChecklistViewer` component. Add it in Lightning
  App Builder.
- The user lacks `CKR_User`. Only `CKR_User` grants the viewer's Apex
  classes; `CKR_Admin` and `CKR_ReadOnly` do not. System Administrators can
  usually load it through their profile.
- The user cannot see the checklist instance under sharing.

## New Checklist shows no templates

- The template has no Published version, or the template is inactive.
- The template targets a different object (its Target Object API Name).

Attaching a second checklist from the same template to one record fails: there
is at most one per record and template.

## A user cannot check items off

The version's completion access mode requires edit access to the record, or a
custom permission the user does not hold. See
[Authoring a template](04-authoring-a-template.md#completion-access-mode).

## I cannot edit a version, item, or rule

It is Published or Historical, so it is frozen. Create a new Draft version. See
[Publishing and new versions](06-publishing-and-new-versions.md).

## I cannot delete a checklist, item, rule, or template

It has audit or bypass history. See [Audit history](09-audit-history.md#append-only).

## The bypass report does not show a blocked save

Only bypassed saves are recorded. Blocked saves that failed leave no record.
