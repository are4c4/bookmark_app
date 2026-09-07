import 'package:drift/drift.dart' show Variable;

import '../data/app_database.dart';
import '../data/core_object_bridge.dart';
import '../data/generic_database_store.dart';
import '../data/image_object_service.dart';
import '../data/object_store.dart';
import '../data/relation_read_service.dart';
import '../data/system_object_store.dart';

/// Read-only compatibility boundary for resolving legacy Photo reverse lookups
/// through canonical Bookmark -> Image Relations during #245 migration.
///
/// This service never repairs, syncs, or falls back to `bookmark_photos`.
/// Missing Photo/Image mirror state fails closed so the legacy Photo UI cannot
/// silently become a second relationship authority again.
class LegacyPhotoBookmarkBacklinkService {
  LegacyPhotoBookmarkBacklinkService(this.database)
      : objectStore = ObjectStore(GenericDatabaseStore(database)) {
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    relationReads = RelationReadService(objectStore);
  }

  final AppDatabase database;
  final ObjectStore objectStore;
  late final SystemObjectStore systemObjects;
  late final RelationReadService relationReads;

  Future<Set<int>> bookmarkIdsForPhoto({
    required int workspaceId,
    required int photoId,
  }) async {
    final imageObjectId = await _imageObjectIdForPhoto(
      workspaceId: workspaceId,
      photoId: photoId,
    );
    if (imageObjectId == null) {
      throw StateError(
        'Legacy Photo must be mirrored before canonical backlink lookup.',
      );
    }

    final bookmarkType = await systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: CoreObjectBridge.bookmarkSystemKey,
    );
    final imageType = await systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
    );
    if (bookmarkType == null || imageType == null) {
      throw StateError(
        'Canonical Bookmark/Image ObjectTypes are required for Photo backlinks.',
      );
    }

    final imageExists = (await objectStore.listObjects(imageType.id))
        .any((image) => image.id == imageObjectId);
    if (!imageExists) {
      throw StateError(
        'Legacy Photo mapping does not resolve to a canonical Image Object.',
      );
    }

    final backlinks = await relationReads.backlinks(
      workspaceId: workspaceId,
      targetObjectId: imageObjectId,
    );
    final bookmarkObjectIds = backlinks
        .where(
          (backlink) =>
              backlink.property.objectTypeId == bookmarkType.id &&
              backlink.property.targetObjectTypeId == imageType.id &&
              (backlink.property.name == 'Images' ||
                  backlink.property.name == 'Cover Image'),
        )
        .map((backlink) => backlink.sourceObject.id)
        .toSet();
    if (bookmarkObjectIds.isEmpty) return const <int>{};

    final rows = await database.customSelect(
      '''SELECT bookmark_id, object_id
         FROM bookmark_object_links
         WHERE workspace_id = ?''',
      variables: <Variable<int>>[Variable<int>(workspaceId)],
    ).get();
    final bookmarkIdByObjectId = <int, int>{
      for (final row in rows)
        row.read<int>('object_id'): row.read<int>('bookmark_id'),
    };

    final unresolvedObjectIds = bookmarkObjectIds
        .where((objectId) => !bookmarkIdByObjectId.containsKey(objectId))
        .toList(growable: false);
    if (unresolvedObjectIds.isNotEmpty) {
      throw StateError(
        'Canonical Bookmark backlink has no legacy Bookmark compatibility mapping.',
      );
    }

    return Set<int>.unmodifiable(
      bookmarkObjectIds.map((objectId) => bookmarkIdByObjectId[objectId]!),
    );
  }

  Future<int?> _imageObjectIdForPhoto({
    required int workspaceId,
    required int photoId,
  }) async {
    final rows = await database.customSelect(
      '''SELECT object_id
         FROM photo_object_links
         WHERE workspace_id = ? AND photo_id = ?
         LIMIT 1''',
      variables: <Variable<int>>[
        Variable<int>(workspaceId),
        Variable<int>(photoId),
      ],
    ).get();
    if (rows.isEmpty) return null;
    return rows.single.read<int>('object_id');
  }
}
