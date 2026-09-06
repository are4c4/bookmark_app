import 'dart:io';

import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'image_object_service.dart';
import 'object_store.dart';
import 'object_type_defaults_store.dart';
import 'relation_mutation_service.dart';
import 'system_object_store.dart';
import 'tag_object_bridge.dart';

class CoreObjectBridge {
  CoreObjectBridge({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
    required this.tagBridge,
  });

  static const photoSystemKey = ImageObjectService.systemKey;
  static const bookmarkSystemKey = 'bookmark';

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  final TagObjectBridge tagBridge;
  Future<void>? _schemaReady;

  late final GenericDatabaseStore _genericStore = GenericDatabaseStore(database);
  late final ImageObjectService _images = ImageObjectService(
        systemObjects: systemObjectStore,
        defaultsStore: ObjectTypeDefaultsStore(_genericStore),
      );
  late final RelationMutationService _relationMutations = RelationMutationService(
        objectStore: objectStore,
        genericStore: _genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: _genericStore,
          objectStore: objectStore,
        ),
      );

  Future<void> ensureSchema() => _schemaReady ??= database.transaction(() async {
        await systemObjectStore.ensureSchema();
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS photo_object_links (
            workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
            photo_id INTEGER NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
            object_id INTEGER NOT NULL REFERENCES generic_records(id) ON DELETE CASCADE,
            PRIMARY KEY(workspace_id, photo_id),
            UNIQUE(workspace_id, object_id)
          )
        ''');
        await database.customStatement('''
          CREATE TABLE IF NOT EXISTS bookmark_object_links (
            workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
            bookmark_id INTEGER NOT NULL REFERENCES bookmarks(id) ON DELETE CASCADE,
            object_id INTEGER NOT NULL REFERENCES generic_records(id) ON DELETE CASCADE,
            PRIMARY KEY(workspace_id, bookmark_id),
            UNIQUE(workspace_id, object_id)
          )
        ''');
      });

  Future<void> syncAll(int workspaceId) async {
    await ensureSchema();
    await tagBridge.syncLegacyTags(workspaceId);
    final tagType = (await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: TagObjectBridge.systemKey,
    ))!;
    final photoType = await _ensurePhotoType(workspaceId);
    final bookmarkType = await _ensureBookmarkType(
      workspaceId,
      photoTypeId: photoType.id,
      tagTypeId: tagType.id,
    );
    await _syncPhotos(workspaceId, photoType);
    await _syncBookmarks(workspaceId, bookmarkType);
  }

  Future<AppObjectType> _ensurePhotoType(int workspaceId) async {
    await _images.ensureDefinition(workspaceId);
    var type = (await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: photoSystemKey,
    ))!;
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Legacy Photo ID',
      type: ObjectPropertyType.number,
      config: const {'system': true, 'hidden': true},
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Legacy Tags',
      type: ObjectPropertyType.text,
      config: const {'system': true, 'hidden': true},
    );
    type = (await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: photoSystemKey,
    ))!;
    return type;
  }

  Future<AppObjectType> _ensureBookmarkType(
    int workspaceId, {
    required int photoTypeId,
    required int tagTypeId,
  }) async {
    final type = await systemObjectStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: bookmarkSystemKey,
      name: 'ブックマーク',
      icon: '🔖',
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Legacy Bookmark ID',
      type: ObjectPropertyType.number,
      config: const {'system': true, 'hidden': true},
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'URL',
      type: ObjectPropertyType.url,
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Description',
      type: ObjectPropertyType.text,
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Favorite',
      type: ObjectPropertyType.checkbox,
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Reading Status',
      type: ObjectPropertyType.select,
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Storage State',
      type: ObjectPropertyType.select,
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Genre',
      type: ObjectPropertyType.select,
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Rating',
      type: ObjectPropertyType.rating,
    );
    await systemObjectStore.ensureRelationProperty(
      objectTypeId: type.id,
      name: 'Images',
      targetObjectTypeId: photoTypeId,
      multiple: true,
    );
    await systemObjectStore.ensureRelationProperty(
      objectTypeId: type.id,
      name: 'Cover Image',
      targetObjectTypeId: photoTypeId,
      multiple: false,
    );
    await systemObjectStore.ensureRelationProperty(
      objectTypeId: type.id,
      name: 'Tags',
      targetObjectTypeId: tagTypeId,
      multiple: true,
    );
    return (await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: bookmarkSystemKey,
    ))!;
  }

  Future<void> _syncPhotos(int workspaceId, AppObjectType photoType) async {
    final photos = await database.select(database.photos).get();
    final validPhotoIds = photos.map((photo) => photo.id).toSet();
    final legacyId = _property(photoType, 'Legacy Photo ID');
    final file = _property(photoType, 'File');
    final note = _property(photoType, 'Note');
    final originalFilename = _property(photoType, 'Original filename');
    final legacyTags = _property(photoType, 'Legacy Tags');

    for (final photo in photos) {
      final title = photo.title?.trim().isNotEmpty == true
          ? photo.title!.trim()
          : '画像 ${photo.id}';
      final link = await _ensurePhotoLinkedObject(
        workspaceId: workspaceId,
        legacyId: photo.id,
        filePath: photo.path,
        title: title,
        photoType: photoType,
        legacyIdProperty: legacyId,
      );
      if (link == null) continue;
      if (link.legacyOwned) {
        await objectStore.renameObject(link.object.id, title);
        await objectStore.setPropertyValue(
          objectId: link.object.id,
          property: legacyId,
          value: photo.id,
        );
        await objectStore.setPropertyValue(
          objectId: link.object.id,
          property: file,
          value: photo.path,
        );
        await objectStore.setPropertyValue(
          objectId: link.object.id,
          property: note,
          value: photo.note,
        );
        await objectStore.setPropertyValue(
          objectId: link.object.id,
          property: originalFilename,
          value: _fileName(photo.path),
        );
        await objectStore.setPropertyValue(
          objectId: link.object.id,
          property: legacyTags,
          value: photo.tags,
        );
      } else {
        // Reusing a pre-existing canonical Image must not turn that Image into a
        // legacy-owned mirror. Preserve its user metadata and ownership while
        // filling only canonical metadata that is currently absent.
        await _setStringIfMissing(link.object, note, photo.note);
        await _setStringIfMissing(
          link.object,
          originalFilename,
          _fileName(photo.path),
        );
      }
    }

    await _removeOrphanObjects(
      workspaceId: workspaceId,
      objectType: photoType,
      legacyIdProperty: legacyId,
      validLegacyIds: validPhotoIds,
    );
  }

  Future<void> _syncBookmarks(int workspaceId, AppObjectType bookmarkType) async {
    final bookmarkIds = (await (database.select(database.bookmarkWorkspaces)
          ..where((row) => row.workspaceId.equals(workspaceId)))
        .get())
        .map((row) => row.bookmarkId)
        .toSet();
    final bookmarks = (await database.select(database.bookmarks).get())
        .where((bookmark) => bookmarkIds.contains(bookmark.id));

    final legacyId = _property(bookmarkType, 'Legacy Bookmark ID');
    final url = _property(bookmarkType, 'URL');
    final description = _property(bookmarkType, 'Description');
    final favorite = _property(bookmarkType, 'Favorite');
    final readingStatus = _property(bookmarkType, 'Reading Status');
    final storageState = _property(bookmarkType, 'Storage State');
    final genre = _property(bookmarkType, 'Genre');
    final rating = _property(bookmarkType, 'Rating');
    final images = _property(bookmarkType, 'Images');
    final coverImage = _property(bookmarkType, 'Cover Image');
    final tags = _property(bookmarkType, 'Tags');

    for (final bookmark in bookmarks) {
      final objectId = await _ensureLinkedObject(
        workspaceId: workspaceId,
        table: 'bookmark_object_links',
        legacyColumn: 'bookmark_id',
        legacyId: bookmark.id,
        objectTypeId: bookmarkType.id,
        title: bookmark.title,
      );
      await objectStore.renameObject(objectId, bookmark.title);
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: legacyId,
        value: bookmark.id,
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: url,
        value: bookmark.url,
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: description,
        value: bookmark.description,
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: favorite,
        value: bookmark.favorite,
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: readingStatus,
        value: bookmark.readingStatus,
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: storageState,
        value: bookmark.storageState,
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: genre,
        value: bookmark.genre,
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: rating,
        value: bookmark.rating,
      );

      final photoRows = await database.customSelect(
        'SELECT photo_id, is_cover FROM bookmark_photos '
        'WHERE bookmark_id = ? ORDER BY is_cover DESC, photo_id',
        variables: [Variable<int>(bookmark.id)],
      ).get();
      final photoObjectIds = <int>[];
      var coverPhotoCount = 0;
      int? coverImageObjectId;
      for (final row in photoRows) {
        final isCover = row.read<int>('is_cover') != 0;
        if (isCover) coverPhotoCount += 1;
        final linked = await _linkedObjectId(
          workspaceId: workspaceId,
          table: 'photo_object_links',
          legacyColumn: 'photo_id',
          legacyId: row.read<int>('photo_id'),
        );
        if (linked == null) continue;
        photoObjectIds.add(linked);
        if (isCover) coverImageObjectId = linked;
      }
      if (coverPhotoCount > 1) {
        throw StateError(
          'Legacy Bookmark ${bookmark.id} has multiple cover photos.',
        );
      }
      if (coverPhotoCount == 1 && coverImageObjectId == null) {
        throw StateError(
          'Legacy Bookmark ${bookmark.id} cover photo has no linked Image Object.',
        );
      }
      await _relationMutations.setRelation(
        objectId: objectId,
        property: images,
        targetObjectIds: photoObjectIds,
      );
      await _relationMutations.setRelation(
        objectId: objectId,
        property: coverImage,
        targetObjectIds: coverImageObjectId == null
            ? const <int>[]
            : <int>[coverImageObjectId],
      );

      final tagRows = await database.customSelect(
        'SELECT tag_id FROM bookmark_tags WHERE bookmark_id = ? ORDER BY tag_id',
        variables: [Variable<int>(bookmark.id)],
      ).get();
      final tagObjectIds = <int>[];
      for (final row in tagRows) {
        final linked = await tagBridge.objectIdForLegacyTag(
          workspaceId,
          row.read<int>('tag_id'),
        );
        if (linked != null) tagObjectIds.add(linked);
      }
      await _relationMutations.setRelation(
        objectId: objectId,
        property: tags,
        targetObjectIds: tagObjectIds,
      );
    }

    await _removeOrphanObjects(
      workspaceId: workspaceId,
      objectType: bookmarkType,
      legacyIdProperty: legacyId,
      validLegacyIds: bookmarkIds,
    );
  }

  ObjectPropertyDefinition _property(AppObjectType type, String name) =>
      type.properties.firstWhere((property) => property.name == name);

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }

  Future<bool> _storedPhotoFileExists(String storedPath) async {
    try {
      final resolved = database.pathResolver.resolveStoredPath(storedPath);
      return await File(resolved).exists();
    } catch (_) {
      // File-system lookup is a compatibility gate only. Keep the legacy Photo
      // row untouched and retry promotion on a later sync if media reappears.
      return false;
    }
  }

  Future<void> _setStringIfMissing(
    AppObject object,
    ObjectPropertyDefinition property,
    String? value,
  ) async {
    final candidate = value?.trim();
    if (candidate == null || candidate.isEmpty) return;
    final current = '${object.values[property.id] ?? ''}'.trim();
    if (current.isNotEmpty) return;
    await objectStore.setPropertyValue(
      objectId: object.id,
      property: property,
      value: candidate,
    );
  }

  Future<void> _removeOrphanObjects({
    required int workspaceId,
    required AppObjectType objectType,
    required ObjectPropertyDefinition legacyIdProperty,
    required Set<int> validLegacyIds,
  }) async {
    final objects = await objectStore.listObjects(objectType.id);
    for (final object in objects) {
      final rawId = object.values[legacyIdProperty.id];
      // Objects without a Legacy ID are native first-class Objects, not stale
      // mirror rows. Keep them alive across compatibility syncs so new Image /
      // Bookmark workflows can coexist with the legacy tables during migration.
      if (rawId == null) continue;
      final legacyId = rawId is int ? rawId : int.tryParse('$rawId');
      if (legacyId != null && validLegacyIds.contains(legacyId)) continue;
      await _relationMutations.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: objectType.id,
        objectId: object.id,
      );
    }
  }

  Future<_PhotoObjectLink?> _ensurePhotoLinkedObject({
    required int workspaceId,
    required int legacyId,
    required String filePath,
    required String title,
    required AppObjectType photoType,
    required ObjectPropertyDefinition legacyIdProperty,
  }) async {
    final existing = await _linkedObjectId(
      workspaceId: workspaceId,
      table: 'photo_object_links',
      legacyColumn: 'photo_id',
      legacyId: legacyId,
    );
    if (existing != null) {
      final objects = await objectStore.listObjects(photoType.id);
      for (final object in objects) {
        if (object.id != existing) continue;
        return _PhotoObjectLink(
          object: object,
          legacyOwned: object.values[legacyIdProperty.id] != null,
        );
      }
      throw StateError('Linked Image Object $existing does not exist.');
    }

    // A first promotion must not mint a canonical Image around a broken legacy
    // file reference. Resolve only for the existence check; the original stored
    // path remains the Image identity so relative/absolute identities are not
    // silently rewritten or conflated. Missing media stays retryable.
    if (!await _storedPhotoFileExists(filePath)) return null;

    final existingIds = (await objectStore.listObjects(photoType.id))
        .map((object) => object.id)
        .toSet();

    // First promotion may reuse an already-managed Image with the exact same
    // canonical File identity. Once linked, the stable mapping is authoritative;
    // no path heuristic is consulted on subsequent compatibility syncs.
    final image = await _images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: filePath,
      title: title,
      originalFilename: _fileName(filePath),
    );
    await database.customStatement(
      'INSERT INTO photo_object_links(workspace_id, photo_id, object_id) VALUES (?, ?, ?)',
      [workspaceId, legacyId, image.id],
    );
    return _PhotoObjectLink(
      object: image,
      legacyOwned: !existingIds.contains(image.id),
    );
  }

  Future<int> _ensureLinkedObject({
    required int workspaceId,
    required String table,
    required String legacyColumn,
    required int legacyId,
    required int objectTypeId,
    required String title,
  }) async {
    final existing = await _linkedObjectId(
      workspaceId: workspaceId,
      table: table,
      legacyColumn: legacyColumn,
      legacyId: legacyId,
    );
    if (existing != null) return existing;
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: title,
    );
    await database.customStatement(
      'INSERT INTO $table(workspace_id, $legacyColumn, object_id) VALUES (?, ?, ?)',
      [workspaceId, legacyId, objectId],
    );
    return objectId;
  }

  Future<int?> _linkedObjectId({
    required int workspaceId,
    required String table,
    required String legacyColumn,
    required int legacyId,
  }) async {
    await ensureSchema();
    final row = await database.customSelect(
      'SELECT object_id FROM $table WHERE workspace_id = ? AND $legacyColumn = ? LIMIT 1',
      variables: [Variable<int>(workspaceId), Variable<int>(legacyId)],
    ).getSingleOrNull();
    return row?.read<int>('object_id');
  }
}

class _PhotoObjectLink {
  const _PhotoObjectLink({required this.object, required this.legacyOwned});

  final AppObject object;
  final bool legacyOwned;
}
