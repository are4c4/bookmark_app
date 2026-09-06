import '../domain/object_model.dart';
import 'database_view_gallery_adapter.dart';
import 'database_view_gallery_cover_source_service.dart';
import 'database_view_store.dart';
import 'object_store.dart';
import 'system_object_store.dart';

/// Resolves the effective Gallery cover source while old Views migrate to the
/// explicit per-View cover setting.
///
/// A persisted setting always wins, including an explicit `none` or malformed
/// payload (which the adapter fails closed to `none`). Only Views that have
/// never persisted `galleryCoverSource` receive compatibility behavior.
/// Existing system ObjectType Galleries historically showed their canonical
/// media automatically, so an unconfigured system type prefers direct Image,
/// then the first schema-defined Image Relation, then a Weblink Relation.
/// User-owned custom ObjectTypes remain `none` until a View/template chooses a
/// source explicitly.
class DatabaseViewGalleryCoverCompatibilityService {
  const DatabaseViewGalleryCoverCompatibilityService({
    required this.objectStore,
    required this.systemObjects,
  });

  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;

  static const _adapter = DatabaseViewGalleryAdapter();

  Future<GalleryCoverSource> effectiveSource({
    required DatabaseViewConfig view,
    required int objectTypeId,
  }) async {
    if (view.settings.containsKey(
      DatabaseViewGalleryAdapter.coverSourceSettingsKey,
    )) {
      return _adapter.decodeCoverSource(view);
    }

    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null || objectType.kind != ObjectTypeKind.system) {
      return const GalleryCoverSource.none();
    }

    final options = await DatabaseViewGalleryCoverSourceService(
      objectStore: objectStore,
      systemObjects: systemObjects,
    ).discover(objectTypeId: objectTypeId);

    GalleryCoverSource? imageRelation;
    GalleryCoverSource? weblinkRelation;
    for (final option in options) {
      switch (option.source.kind) {
        case GalleryCoverSourceKind.directImage:
          return option.source;
        case GalleryCoverSourceKind.imageRelation:
          imageRelation ??= option.source;
        case GalleryCoverSourceKind.weblinkRelationRepresentativeImage:
          weblinkRelation ??= option.source;
        case GalleryCoverSourceKind.none:
          break;
      }
    }
    return imageRelation ?? weblinkRelation ?? const GalleryCoverSource.none();
  }
}
