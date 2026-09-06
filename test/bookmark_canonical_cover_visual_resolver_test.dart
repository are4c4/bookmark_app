import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/bookmark_read_store.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_visual_resolver.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'canonical Cover Image precedes legacy cover and missing file falls back',
    () async {
      final directory =
          await Directory.systemTemp.createTemp('bookmark_cover_visual_');
      addTearDown(() => directory.delete(recursive: true));
      final managedDirectory = Directory('${directory.path}/managed');
      await managedDirectory.create(recursive: true);
      final canonicalFile = File('${managedDirectory.path}/canonical.jpg');
      final legacyFile = File('${directory.path}/legacy.jpg');
      await canonicalFile.writeAsBytes(const <int>[1, 2, 3]);
      await legacyFile.writeAsBytes(const <int>[4, 5, 6]);

      final database = AppDatabase.forTesting(
        NativeDatabase.memory(),
        profileDirectoryPath: directory.path,
      );
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();

      await database.customStatement(
        'INSERT INTO photos(path, title) VALUES (?, ?)',
        <Object>[legacyFile.path, 'Legacy cover'],
      );
      final photoId = (await database.customSelect(
        'SELECT id FROM photos LIMIT 1',
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmarks(url, title) VALUES (?, ?)',
        const <Object>['https://example.com/cover', 'Cover bookmark'],
      );
      final bookmarkId = (await database.customSelect(
        'SELECT id FROM bookmarks LIMIT 1',
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        <Object>[bookmarkId, workspaceId],
      );
      await database.customStatement(
        'INSERT INTO bookmark_photos(bookmark_id, photo_id, is_cover) VALUES (?, ?, 1)',
        <Object>[bookmarkId, photoId],
      );

      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);
      await sync.syncWorkspace(workspaceId);

      final genericStore = GenericDatabaseStore(database);
      final image = await ImageObjectService(
        systemObjects: sync.systemObjectStore,
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      ).findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: 'managed/canonical.jpg',
        title: 'Canonical cover',
      );
      final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.bookmarkSystemKey,
      ))!;
      final bookmarkObject =
          (await sync.objectStore.listObjects(bookmarkType.id)).single;
      final coverProperty = bookmarkType.properties.singleWhere(
        (property) => property.name == 'Cover Image',
      );
      final mutations = RelationMutationService(
        objectStore: sync.objectStore,
        genericStore: genericStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: sync.objectStore,
        ),
      );
      await mutations.setRelation(
        objectId: bookmarkObject.id,
        property: coverProperty,
        targetObjectIds: <int>[image.id],
      );

      final bookmark = (await BookmarkReadStore(database).watchItems().first)
          .singleWhere((item) => item.id == bookmarkId);
      final resolver = BookmarkVisualResolver(
        database: database,
        workspaceId: workspaceId,
      );

      final canonical = await resolver.resolve(bookmark);
      expect(canonical?.kind, BookmarkVisualSourceKind.canonicalCover);
      expect(canonical?.value, canonicalFile.path);

      await canonicalFile.delete();
      final fallback = await resolver.resolve(bookmark);
      expect(fallback?.kind, BookmarkVisualSourceKind.userCover);
      expect(fallback?.value, legacyFile.path);
    },
  );
}
