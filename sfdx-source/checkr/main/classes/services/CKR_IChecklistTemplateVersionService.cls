/**
 * Publication contract for making a draft checklist template version active.
 */
public interface CKR_IChecklistTemplateVersionService {
  /**
   * Makes a draft active and retires the previously published version.
   * @param templateVersionId version ID selected for publication
   */
  void publish(Id templateVersionId);
}
