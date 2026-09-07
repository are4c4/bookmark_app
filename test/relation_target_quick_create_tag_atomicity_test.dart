import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_target_quick_create_policy.dart';
import 'package:bookmark_app/data/relation_target_quick_create_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tag quick-create rolls back legacy row and Object projection together',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final tagBridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
    );
    final defaults = ObjectTypeDefaultsStore(genericStore);
    final quickCreate = RelationTargetQuickCreateService(
      policy: RelationTargetQuickCreatePolicy(
        objectStore: objectStore,
        systemObjects: systemObjects,
      ),
      objectStore: objectStore,
      tagBridge: tagBridge,
      weblinks: WeblinkObjectService(
        systemObjects: systemObjects,
        defaultsStore: defaults,
      ),
    );
    final schema = await tagBridge.ensureTagObjectType(workspaceId);

    await database.customStatement('''
      CREATE TRIGGER fail_tag_quick_create_parent_projection
      BEFORE INSERT ON generic_values
      WHEN NEW.property_id = ${schema.parentProperty.id}
      BEGIN
        SELECT RAISE(ABORT, 'forced Tag quick-create Parent projection failure');
      END
    ''');

    await expectLater(
      quickCreate.create(
        workspaceId: workspaceId,
        targetObjectTypeId: schema.objectType.id,
        input: 'Atomic Tag',
      ),
      throwsA(anything),
    );

    final legacyCount = (await database.customSelect(
      "SELECT COUNT(*) AS count FROM tags WHERE name = 'Atomic Tag'",
    ).getSingle())
        .read<int>('count');
    expect(
      legacyCount,
      0,
      reason: 'the legacy Tag row must roll back with failed projection',
    );
    expect(
      await objectStore.listObjects(schema.objectType.id),
      isEmpty,
      reason: 'the canonical Tag Object must roll back too',
    );
    final linkCount = (await database.customSelect(
      'SELECT COUNT(*) AS count FROM tag_object_links '
      'WHERE workspace_id = $workspaceId',
    ).getSingle())
        .read<int>('count');
    expect(linkCount, 0);

    // The failed outer transaction may have rolled back first-time Relation
    // index schema creation. The cached readiness guard must allow the next read
    // to recreate it rather than exposing a no-such-table failure.
    expect(await objectStore.outgoingRelations(-1), isEmpty);
  });
}
