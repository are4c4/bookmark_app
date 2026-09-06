import '../domain/object_model.dart';
import '../services/image_object_service.dart';
import 'database_view_gallery_adapter.dart';
import 'object_store.dart';
import 'system_object_store.dart';
import 'weblink_object_service.dart';

class GalleryCoverSourceOption {
  const GalleryCoverSourceOption({
    required this.source,
    required this.label,
  });

  final GalleryCoverSource source;
  final String label;
}

/// Derives eligible generic Gallery media sources from one ObjectType schema.
///
/// Discovery is intentionally read-only. Relation identity/cardinality and
/// mutation semantics remain owned by ObjectStore/Relation services; this class
/// only decides which existing schema Properties can be presented as Gallery
/// cover choices.
class DatabaseViewGalleryCoverSourceService {
  const DatabaseViewGalleryCoverSourceService({
    required this.objectStore,
    required this.systemObjects,
  });

  final ObjectStore objectStore;
  final SystemObjectStore systemObjects;

  Future<List<GalleryCoverSourceOption>> discover({
    required int objectTypeId,
  }) async {
    final objectType = await objectStore.getObjectType(objectTypeId);
    if (objectType == null) {
      return const <GalleryCoverSourceOption>[
        GalleryCoverSourceOption(
          source: GalleryCoverSource.none(),
          label: 'なし',
        ),
      ];
    }

    final options = <GalleryCoverSourceOption>[
      const GalleryCoverSourceOption(
        source: GalleryCoverSource.none(),
        label: 'なし',
      ),
    ];

    final sourceSystemKey = await systemObjects.systemKeyForObjectType(
      objectType.id,
    );
    if (sourceSystemKey == ImageObjectService.systemKey) {
      options.add(
        const GalleryCoverSourceOption(
          source: GalleryCoverSource.directImage(),
          label: 'このImage',
        ),
      );
    }

    final targetSystemKeys = <int, String?>{};
    for (final property in objectType.properties) {
      if (!property.isRelation) continue;
      final targetTypeId = property.targetObjectTypeId;
      if (targetTypeId == null) continue;

      final targetType = await objectStore.getObjectType(targetTypeId);
      if (targetType == null || targetType.workspaceId != objectType.workspaceId) {
        continue;
      }

      final targetSystemKey = targetSystemKeys.putIfAbsent(
        targetTypeId,
        () => null,
      );
      final resolvedSystemKey = targetSystemKey ??
          await systemObjects.systemKeyForObjectType(targetTypeId);
      targetSystemKeys[targetTypeId] = resolvedSystemKey;

      if (resolvedSystemKey == ImageObjectService.systemKey) {
        options.add(
          GalleryCoverSourceOption(
            source: GalleryCoverSource.imageRelation(property.id),
            label: '${property.name} · Image',
          ),
        );
      } else if (resolvedSystemKey == WeblinkObjectService.systemKey) {
        options.add(
          GalleryCoverSourceOption(
            source: GalleryCoverSource.weblinkRelationRepresentativeImage(
              property.id,
            ),
            label: '${property.name} · Weblinkの代表画像',
          ),
        );
      }
    }

    return options;
  }
}
