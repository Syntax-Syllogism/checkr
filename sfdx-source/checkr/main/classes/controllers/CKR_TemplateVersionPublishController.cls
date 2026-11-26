/**
 * Exposes template publication to the administrative action.
 */
public with sharing class CKR_TemplateVersionPublishController {
  /**
   * Publishes the selected draft through the configured version service.
   * @param templateVersionId version ID selected for publication
   */
  @AuraEnabled
  public static void publishVersion(Id templateVersionId) {
    try {
      (
        (CKR_IChecklistTemplateVersionService) CKR_AppFactory.getInstance(
          CKR_IChecklistTemplateVersionService.class
        )
      ).publish(templateVersionId);
    } catch (Exception failure) {
      throw new AuraHandledException(failure.getMessage());
    }
  }
}
