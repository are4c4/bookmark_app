import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_detail_content_loader.dart';
import 'package:bookmark_app/data/object_detail_session_loader.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail session combines shared content with persisted defaults', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Article',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Shared',
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(openMode: ObjectOpenMode.centerPeek),
    );

    final loader = ObjectDetailSessionLoader(
      contentLoader: ObjectDetailContentLoader(
        objectStore: objectStore,
        bodyStore: ObjectBodyStore(genericStore),
        computedStore: ObjectComputedValueStore(objectStore),
      ),
      defaultsService: ObjectTypeDefaultsService(store: defaultsStore),
      appFallback: const ObjectTypeDefaults(openMode: ObjectOpenMode.sidePeek),
    );

    final session = await loader.load(objectTypeId: typeId, objectId: objectId);

    expect(session?.content.object.title, 'Shared');
    expect(session?.defaults.openMode, ObjectOpenMode.centerPeek);
  });
}
