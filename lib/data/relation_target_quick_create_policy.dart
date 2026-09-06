import '../domain/object_model.dart';
import 'file_object_service.dart';
import 'image_object_service.dart';
import 'object_store.dart';
import 'system_object_store.dart';
import 'tag_object_bridge.dart';
import 'weblink_object_service.dart';

enum RelationTargetQuickCreateMode {
  genericObject,
  tag,
  weblinkUrl,
  managedImage,
  managedFile,
  unavailable,
}

/// Classifies which creation affordance a Relation target picker may expose.
///
/// This is deliberately read-only. It prevents generic presentation from using
/// title-only Object creation for identity-sensitive built-in primitives. The
/// actual mutations remain delegated to the canonical Tag/Weblink/Image/File or
/// normal Object creation boundaries selected by the host.
class RelationTargetQuickCreatePolicy {
  const RelationTargetQuickCreatePolicy({
    required this.objectStore,
    required this.systemObjects,
  });

  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;

  Future<RelationTargetQuickCreateMode> modeFor({
    required int workspaceId,
    required int targetObjectTypeId,
  }) async {
    final target = await objectStore.getObjectType(targetObjectTypeId);
    if (target == null || target.workspaceId != workspaceId) {
      return RelationTargetQuickCreateMode.unavailable;
    }
    if (target.kind == ObjectTypeKind.custom) {
      return RelationTargetQuickCreateMode.genericObject;
    }

    final systemKey = await systemObjects.systemKeyForObjectType(
      targetObjectTypeId,
    );
    return switch (systemKey) {
      TagObjectBridge.systemKey => RelationTargetQuickCreateMode.tag,
      WeblinkObjectService.systemKey => RelationTargetQuickCreateMode.weblinkUrl,
      ImageObjectService.systemKey => RelationTargetQuickCreateMode.managedImage,
      FileObjectService.systemKey => RelationTargetQuickCreateMode.managedFile,
      _ => RelationTargetQuickCreateMode.unavailable,
    };
  }
}
