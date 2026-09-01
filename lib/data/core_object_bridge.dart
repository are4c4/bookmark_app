import 'package:drift/drift.dart';

import '../domain/object_model.dart';
import 'app_database.dart';
import 'object_store.dart';
import 'system_object_store.dart';
import 'tag_object_bridge.dart';

class CoreObjectBridge {
  CoreObjectBridge({
    required this.database,
    required this.objectStore,
    required this.systemObjectStore,
    required this.tagBridge,
  });

  static const photoSystemKey = 'image';
  static const bookmarkSystemKey = 'bookmark';

  final AppDatabase database;
  final ObjectStore objectStore;
  final SystemObjectStore systemObjectStore;
  final TagObjectBridge tagBridge;
  Future<void>? _schemaReady;

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
    final type = await systemObjectStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: photoSystemKey,
      name: '画像',
      icon: '🖼️',
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Legacy Photo ID',
      type: ObjectPropertyType.number,
      config: const {'system': true, 'hidden': true},
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'File',
      type: ObjectPropertyType.file,
      config: const {'system': true},
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Note',
      type: ObjectPropertyType.text,
    );
    await systemObjectStore.ensureProperty(
      objectTypeId: type.id,
      name: 'Legacy Tags',
      type: ObjectPropertyType.text,
      config: const {'system': true, 'hidden': true},
    );
    return (await systemObjectStore.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: photoSystemKey,
    ))!;
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
    final legacyId = _property(photoType, 'Legacy Photo ID');
    final file = _property(photoType, 'File');
    final note = _property(photoType, 'Note');
    final legacyTags = _property(photoType, 'Legacy Tags');

    for (final photo in photos) {
      final title = photo.title?.trim().isNotEmpty == true
          ? photo.title!.trim()
          : '画像 ${photo.id}';
      final objectId = await _ensureLinkedObject(
        workspaceId: workspaceId,
        table: 'photo_object_links',
        legacyColumn: 'photo_id',
        legacyId: photo.id,
        objectTypeId: photoType.id,
        title: title,
      );
      await objectStore.renameObject(objectId, title);
      await objectStore.setPropertyValue(objectId: objectId, property: legacyId, value: photo.id);
      await objectStore.setPropertyValue(objectId: objectId, property: file, value: photo.path);
      await objectStore.setPropertyValue(objectId: objectId, property: note, value: photo.note);
      await objectStore.setPropertyValue(objectId: objectId, property: legacyTags, value: photo.tags);
    }
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
      await objectStore.setPropertyValue(objectId: objectId, property: legacyId, value: bookmark.id);
      await objectStore.setPropertyValue(objectId: objectId, property: url, value: bookmark.url);
      await objectStore.setPropertyValue(objectId: objectId, property: description, value: bookmark.description);
      await objectStore.setPropertyValue(objectId: objectId, property: favorite, value: bookmark.favorite);
      await objectStore.setPropertyValue(objectId: objectId, property: readingStatus, value: bookmark.readingStatus);
      await objectStore.setPropertyValue(objectId: objectId, property: storageState, value: bookmark.storageState);
      await objectStore.setPropertyValue(objectId: objectId, property: genre, value: bookmark.genre);
      await objectStore.setPropertyValue(objectId: objectId, property: rating, value: bookmark.rating);

      final photoRows = await database.customSelect(
        'SELECT photo_id FROM bookmark_photos WHERE bookmark_id = ? ORDER BY is_cover DESC, photo_id',
        variables: [Variable<int>(bookmark.id)],
      ).get();
      final photoObjectIds = <int>[];
      for (final row in photoRows) {
        final linked = await _linkedObjectId(
          workspaceId: workspaceId,
          table: 'photo_object_links',
          legacyColumn: 'photo_id',
          legacyId: row.read<int>('photo_id'),
        );
        if (linked != null) photoObjectIds.add(linked);
      }
      await objectStore.setRelation(
        objectId: objectId,
        property: images,
        targetObjectIds: photoObjectIds,
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
      await objectStore.setRelation(
        objectId: objectId,
        property: tags,
        targetObjectIds: tagObjectIds,
      );
    }
  }

  ObjectPropertyDefinition _property(AppObjectType type, String name) =>
      type.properties.firstWhere((property) => property.name == name);

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
    final objectId = await objectStore.createObject(objectTypeId: objectTypeId, title: title);
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
