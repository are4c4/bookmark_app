import '../domain/object_type_defaults.dart';
import 'database_view_open_mode_service.dart';
import 'database_view_store.dart';
import 'object_type_defaults_store.dart';

/// Resolves the actual Object presentation mode for a Database View without
/// making page widgets coordinate View and ObjectType persistence themselves.
class ObjectOpenPresentationService {
  const ObjectOpenPresentationService({
    required this.viewOpenModes,
    required this.objectTypeDefaults,
  });

  final DatabaseViewOpenModeService viewOpenModes;
  final ObjectTypeDefaultsStore objectTypeDefaults;

  Future<ObjectOpenMode> resolve({
    required DatabaseViewConfig view,
    required int objectTypeId,
    ObjectOpenMode? databaseOverride,
    ObjectOpenMode appFallback = ObjectOpenMode.sidePeek,
  }) async {
    final typeDefaults = await objectTypeDefaults.read(objectTypeId);
    return viewOpenModes.resolve(
      view: view,
      databaseOverride: databaseOverride,
      objectTypeDefault: typeDefaults?.openMode,
      appFallback: appFallback,
    );
  }
}
