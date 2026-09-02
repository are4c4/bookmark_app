import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persisted ObjectType defaults override app fallback only where set', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final store = ObjectTypeDefaultsStore(genericStore);
    final service = ObjectTypeDefaultsService(store: store);
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );

    await store.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(
        visiblePropertyIds: <int>[2, 1],
        openMode: ObjectOpenMode.fullPage,
      ),
    );

    final resolved = await service.resolve(
      objectTypeId: typeId,
      appFallback: const ObjectTypeDefaults(
        visiblePropertyIds: <int>[9],
        propertyOrder: <int>[9, 8],
        openMode: ObjectOpenMode.sidePeek,
      ),
    );

    expect(resolved.visiblePropertyIds, <int>[2, 1]);
    expect(resolved.propertyOrder, <int>[9, 8]);
    expect(resolved.openMode, ObjectOpenMode.fullPage);
  });

  test('missing persisted defaults use app fallback', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = ObjectTypeDefaultsService(
      store: ObjectTypeDefaultsStore(genericStore),
    );
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Plain',
    );

    final resolved = await service.resolve(
      objectTypeId: typeId,
      appFallback: const ObjectTypeDefaults(
        visiblePropertyIds: <int>[1],
        propertyOrder: <int>[1],
        openMode: ObjectOpenMode.centerPeek,
      ),
    );

    expect(resolved.visiblePropertyIds, <int>[1]);
    expect(resolved.propertyOrder, <int>[1]);
    expect(resolved.openMode, ObjectOpenMode.centerPeek);
  });
}
