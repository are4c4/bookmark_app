import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Bookmark reconciliation preserves legacy URL on canonical Weblink collision',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final sync = ObjectSyncService(database);
      addTearDown(sync.dispose);

      await database.customStatement(
        "INSERT INTO bookmarks(url, title) VALUES ('https://example.com/article', 'Legacy')",
      );
      final bookmarkId = (await database.customSelect(
        "SELECT id FROM bookmarks WHERE title = 'Legacy'",
      ).getSingle())
          .read<int>('id');
      await database.customStatement(
        'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
        [bookmarkId, workspaceId],
      );

      await sync.coreBridge.syncAll(workspaceId);
      final bookmarkType = (await sync.systemObjectStore.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.bookmarkSystemKey,
      ))!;
      final legacyUrlProperty = bookmarkType.properties.singleWhere(
        (property) => property.name == 'URL',
      );
      final bookmarkObject =
          (await sync.objectStore.listObjects(bookmarkType.id)).single;
      expect(
        bookmarkObject.values[legacyUrlProperty.id],
        'https://example.com/article',
      );

      final genericStore = GenericDatabaseStore(database);
      final weblinks = WeblinkObjectService(
        systemObjects: sync.systemObjectStore,
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );
      final definition = await weblinks.ensureDefinition(workspaceId);
      await weblinks.findOrCreate(
        workspaceId: workspaceId,
        url: 'https://example.com/article',
        title: 'First canonical candidate',
      );
      final duplicateId = await sync.objectStore.createObject(
        objectTypeId: definition.objectType.id,
        title: 'Second canonical candidate',
      );
      await sync.objectStore.setPropertyValue(
        objectId: duplicateId,
        property: definition.urlProperty,
        value: 'HTTPS://Example.COM:443/article',
      );

      await expectLater(
        sync.bookmarkWeblinkBridge.syncWorkspace(workspaceId),
        throwsA(isA<StateError>()),
      );

      final refreshedBookmark = (await sync.objectStore.listObjects(
        bookmarkType.id,
      ))
          .singleWhere((object) => object.id == bookmarkObject.id);
      expect(
        refreshedBookmark.values[legacyUrlProperty.id],
        'https://example.com/article',
      );
      expect(
        await sync.objectStore.outgoingRelations(bookmarkObject.id),
        isEmpty,
      );
      final preservedLegacyUrl = await database.customSelect(
        'SELECT url FROM bookmarks WHERE id = ?',
        variables: [Variable<int>(bookmarkId)],
      ).getSingle();
      expect(
        preservedLegacyUrl.read<String>('url'),
        'https://example.com/article',
      );
      expect(
        await sync.objectStore.listObjects(definition.objectType.id),
        hasLength(2),
      );
    },
  );
}
