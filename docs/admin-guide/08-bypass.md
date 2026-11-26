---
title: "Bypass for data loads and integrations"
---

Gate bypass lets a user's saves through gates that would block them. It is off
by default, and **every bypassed save is recorded** as a Gate Bypass Event in
the same transaction; if that record cannot be written, the save fails too.
Bypass skips only CheckR gates. Object permissions, validation rules, and other
automation still apply.

There are two switches. Use the narrowest one, for the shortest time.

## Option 1: the CheckR Gate Bypass permission set (preferred)

1. Assign `CKR_GateBypass` to the data-load or integration user.
2. Run the load.
3. Remove the assignment.

## Option 2: the CheckR Settings hierarchy switch

1. Open **Setup → Custom Settings → CheckR Settings → Manage**.
2. Add a **user** row (preferred for integrations) or a profile row, and check
   **Bypass Gate**. Use an organization row only for a coordinated break-glass
   window.
3. Run the load.
4. Uncheck or delete the row.

The most specific row wins, so a user or profile row with Bypass Gate unchecked
overrides an organization row that is checked. When both the permission set and
the setting apply, the event records **CustomPermission** as the source.
Changes take effect in the next transaction.

## Review what was bypassed

Each event records the actor, record, object, first blocking rule, time, source,
and the error that would have shown. Use the
**Gate bypasses by actor and object** report (see [Reports](10-reports.md)) or
the query in [gate bypass operations](../gate-bypass.md). Compare them with the
maintenance request. Only saves that a gate would have blocked produce events.

Who may hold bypass, and why it is separate from `CKR_Admin`, is in the
[security reference](../security.md#gate-bypass).
