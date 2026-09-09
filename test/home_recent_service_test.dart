import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/home_recent_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'returns recently changed Objects across ObjectTypes in global order',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final store = GenericDatabaseStore(database);
      final objectStore = ObjectStore(store);
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );

      final notesTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Notes',
        icon: '📝',
      );
      final peopleTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'People',
        icon: '👤',
      );
      final oldId = await objectStore.createObject(
        objectTypeId: notesTypeId,
        title: 'Old note',
      );
      final newestId = await objectStore.createObject(
        objectTypeId: peopleTypeId,
        title: 'Newest person',
      );
      final middleId = await objectStore.createObject(
        objectTypeId: notesTypeId,
        title: 'Middle note',
      );

      await database.customStatement(
        "UPDATE generic_records SET updated_at = '2026-09-01 10:00:00' WHERE id = ?",
        [oldId],
      );
      await database.customStatement(
        "UPDATE generic_records SET updated_at = '2026-09-03 10:00:00' WHERE id = ?",
        [newestId],
      );
      await database.customStatement(
        "UPDATE generic_records SET updated_at = '2026-09-02 10:00:00' WHERE id = ?",
        [middleId],
      );

      final recent = await HomeRecentService(
        objectStore: objectStore,
        systemObjects: systemObjects,
      ).listRecentlyChanged(workspaceId: workspaceId);

      expect(recent.map((item) => item.object.id), <int>[
        newestId,
        middleId,
        oldId,
      ]);
      expect(recent.first.objectType.name, 'People');
      expect(recent[1].objectType.name, 'Notes');
    },
  );

  test(
    'respects limit and uses Object id as deterministic timestamp tie-break',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final store = GenericDatabaseStore(database);
      final objectStore = ObjectStore(store);
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final typeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Notes',
      );
      final firstId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'First',
      );
      final secondId = await objectStore.createObject(
        objectTypeId: typeId,
        title: 'Second',
      );
      await database.customStatement(
        "UPDATE generic_records SET updated_at = '2026-09-01 10:00:00' WHERE id IN (?, ?)",
        [firstId, secondId],
      );

      final service = HomeRecentService(
        objectStore: objectStore,
        systemObjects: systemObjects,
      );
      final recent = await service.listRecentlyChanged(
        workspaceId: workspaceId,
        limit: 1,
      );

      expect(recent, hasLength(1));
      expect(recent.single.object.id, secondId);
      expect(
        await service.listRecentlyChanged(workspaceId: workspaceId, limit: 0),
        isEmpty,
      );
    },
  );

  test(
    'hides bookmark compatibility mirrors but keeps user-facing system Objects',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final store = GenericDatabaseStore(database);
      final objectStore = ObjectStore(store);
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );

      final bookmarkType = await systemObjects.ensureSystemObjectType(
        workspaceId: workspaceId,
        systemKey: CoreObjectBridge.bookmarkSystemKey,
        name: 'Migrated links',
        icon: '🔖',
      );
      final weblinkType = await systemObjects.ensureSystemObjectType(
        workspaceId: workspaceId,
        systemKey: WeblinkObjectService.systemKey,
        name: 'Weblinks',
        icon: '🔗',
      );
      final legacyMirrorId = await objectStore.createObject(
        objectTypeId: bookmarkType.id,
        title: 'Legacy mirror',
      );
      final canonicalId = await objectStore.createObject(
        objectTypeId: weblinkType.id,
        title: 'Canonical Weblink',
      );
      await database.customStatement(
        "UPDATE generic_records SET updated_at = '2026-09-04 10:00:00' WHERE id = ?",
        [legacyMirrorId],
      );
      await database.customStatement(
        "UPDATE generic_records SET updated_at = '2026-09-03 10:00:00' WHERE id = ?",
        [canonicalId],
      );

      final recent = await HomeRecentService(
        objectStore: objectStore,
        systemObjects: systemObjects,
      ).listRecentlyChanged(workspaceId: workspaceId);

      expect(recent.map((item) => item.object.id), <int>[canonicalId]);
      expect(recent.single.objectType.id, weblinkType.id);
    },
  );
}
