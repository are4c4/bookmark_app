import '../domain/object_detail_session.dart';
import '../domain/object_type_defaults.dart';
import 'object_detail_content_loader.dart';
import 'object_type_defaults_service.dart';

/// Loads Object-owned detail state in one call for side/center/full-page hosts.
class ObjectDetailSessionLoader {
  ObjectDetailSessionLoader({
    required this.contentLoader,
    required this.defaultsService,
    required this.appFallback,
  });

  final ObjectDetailContentLoader contentLoader;
  final ObjectTypeDefaultsService defaultsService;
  final ObjectTypeDefaults appFallback;

  Future<ObjectDetailSession?> load({
    required int objectTypeId,
    required int objectId,
  }) async {
    final content = await contentLoader.load(
      objectTypeId: objectTypeId,
      objectId: objectId,
    );
    if (content == null) return null;
    final defaults = await defaultsService.resolve(
      objectTypeId: objectTypeId,
      appFallback: appFallback,
    );
    return ObjectDetailSession(content: content, defaults: defaults);
  }
}
