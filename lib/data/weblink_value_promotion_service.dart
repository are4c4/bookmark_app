import '../domain/object_model.dart';
import 'object_value_promotion_execution_service.dart';
import 'weblink_object_service.dart';

/// Object-lane facade for promoting a URL Value into a reusable Weblink Object.
///
/// Weblink creation/reuse remains owned by [WeblinkObjectService], while the
/// actual link write is delegated to the generic promotion executor and then to
/// the Relation-lane mutation facade. The original URL is preserved by default.
class WeblinkValuePromotionService {
  const WeblinkValuePromotionService({
    required this.weblinks,
    required this.executor,
  });

  final WeblinkObjectService weblinks;
  final ObjectValuePromotionExecutionService executor;

  Future<ObjectValuePromotionExecutionResult> promote({
    required int workspaceId,
    required int sourceObjectId,
    required ObjectPropertyDefinition sourceProperty,
    required String url,
    String? title,
    String relationPropertyName = 'Weblink',
  }) async {
    final target = await weblinks.ensureDefinition(workspaceId);
    final plan = weblinks.planUrlPromotion(
      sourceProperty: sourceProperty,
      sourceValue: url,
      target: target,
      relationPropertyName: relationPropertyName,
      title: title,
    );
    final weblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: url,
      title: title,
    );
    return executor.execute(
      plan: plan,
      sourceObjectId: sourceObjectId,
      targetObjectId: weblink.id,
    );
  }
}
