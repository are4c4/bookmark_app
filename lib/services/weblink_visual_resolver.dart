import 'dart:io';

import '../data/object_store.dart';
import '../data/relation_read_service.dart';
import '../data/weblink_image_schema_service.dart';

class WeblinkManagedVisual {
  const WeblinkManagedVisual({
    required this.imageObjectId,
    required this.filePath,
  });

  final int imageObjectId;
  final String filePath;
}

/// Resolves a Weblink's managed Representative Image for presentation only.
///
/// This reader deliberately consumes the canonical Relation index through
/// [RelationReadService]. It never ensures schema, mutates Relation state, or
/// tries to repair ambiguous/missing data. Generic Weblink detail/Gallery hosts
/// and legacy Bookmark presentation can therefore share one fail-closed path.
class WeblinkVisualResolver {
  WeblinkVisualResolver(ObjectStore objectStore)
      : _objectStore = objectStore,
        _relationReads = RelationReadService(objectStore);

  final ObjectStore _objectStore;
  final RelationReadService _relationReads;

  Future<WeblinkManagedVisual?> resolveManagedRepresentative({
    required int weblinkObjectTypeId,
    required int weblinkObjectId,
  }) async {
    if (weblinkObjectTypeId <= 0 || weblinkObjectId <= 0) return null;

    final outgoing = await _relationReads.outgoing(
      sourceObjectTypeId: weblinkObjectTypeId,
      sourceObjectId: weblinkObjectId,
    );
    final representatives = outgoing
        .where(
          (entry) =>
              entry.property.name ==
                  WeblinkImageSchemaService.representativeImageName &&
              !entry.property.allowsMultipleRelations &&
              entry.property.targetObjectTypeId != null,
        )
        .toList(growable: false);
    if (representatives.length != 1) return null;

    final representative = representatives.single;
    final imageTypeId = representative.property.targetObjectTypeId!;
    if (representative.targetObject.objectTypeId != imageTypeId) return null;

    final imageType = await _objectStore.getObjectType(imageTypeId);
    if (imageType == null) return null;
    final fileProperties = imageType.properties
        .where((property) => property.name == 'File')
        .toList(growable: false);
    if (fileProperties.length != 1) return null;

    final path = _nonEmpty(
      representative.targetObject.values[fileProperties.single.id]?.toString(),
    );
    if (path == null || !await _existingFile(path)) return null;

    return WeblinkManagedVisual(
      imageObjectId: representative.targetObject.id,
      filePath: path,
    );
  }

  Future<bool> _existingFile(String path) async {
    try {
      return File(path).exists();
    } catch (_) {
      return false;
    }
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
