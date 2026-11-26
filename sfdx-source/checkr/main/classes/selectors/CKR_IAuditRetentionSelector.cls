/**
 * Finds records protected by CheckR's append-only audit history.
 */
public interface CKR_IAuditRetentionSelector {
  /**
   * Finds templates with a bypass-referenced gate rule in any version.
   * @param templateIds templates considered for deletion
   * @return protected template IDs
   */
  Set<Id> selectBypassReferencedTemplateIds(Set<Id> templateIds);

  /**
   * Finds versions with a bypass-referenced gate rule.
   * @param versionIds versions considered for deletion
   * @return protected version IDs
   */
  Set<Id> selectBypassReferencedVersionIds(Set<Id> versionIds);

  /**
   * Finds checklist instances whose audit events must be retained.
   * @param instanceIds instances considered for deletion
   * @return audited instance IDs
   */
  Set<Id> selectAuditedInstanceIds(Set<Id> instanceIds);

  /**
   * Finds checklist items whose audit lookups must be retained.
   * @param itemIds items considered for deletion
   * @return audited item IDs
   */
  Set<Id> selectAuditedItemIds(Set<Id> itemIds);
}
