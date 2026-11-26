# Gate bypass operations

Assign `CKR_GateBypass` only to trusted data-load operators or integration users
for a defined maintenance window. `CKR_Admin` does not enable bypass. Normal
Account/object permissions and other validation still apply.

For a load, assign the dedicated permission set, perform the load, then remove
the assignment. Alternatively, open Setup → Custom Settings → CheckR Settings →
Manage and enable Bypass Gate on a user, profile, or organization row. Prefer a
user row for integrations; use an org row only for a coordinated break-glass
window. Disable or remove the row afterwards. The most specific row wins;
a user/profile false can override an org true. The custom permission wins when
both switches apply. Changes take effect in the next transaction.

The hierarchy setting has Public visibility so subscriber administrators can
manage it. Salesforce documents [Public custom settings](https://help.salesforce.com/s/articleView?id=platform.cs_schema_settings.htm&language=en_US&type=5)
as subscriber-accessible; Protected settings in managed packages are scoped to
package code. This project uses no namespace. Package-version validation remains part of the release workflow.

Review Gate Bypass Events using an administrator with `CKR_Admin`:

```sql
SELECT CKR_Actor__c, CKR_RecordId__c, CKR_ObjectApiName__c,
       CKR_GateRule__c, CKR_Source__c, CKR_OccurredOn__c, CKR_Details__c
FROM CKR_GateBypassEvent__c
ORDER BY CKR_OccurredOn__c DESC
```

Only saves that a gate would block produce events. Review actor, record, rule,
time and source against the maintenance request. Audit failures abort the save.
A saved event is transactional evidence of bypass, not of failed/rolled-back
attempts. The **Gate bypasses by actor and object** report summarizes the last
30 days; see the [admin guide](admin-guide/10-reports.md#operational-reporting). It records
only the first blocking rule per record.
