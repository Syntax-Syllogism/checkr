/**
 * Reference Account trigger shim for routing before-save changes into Checkr gates.
 */
trigger CKR_AccountTrigger on Account(before insert, before update) {
  CKR_ChecklistTriggerGateway.handleBefore(
    'Account',
    Trigger.oldMap,
    Trigger.newMap
  );
}
