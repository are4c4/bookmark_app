import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('managed Image stores reusable pixel geometry without exposing it by default',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final service = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: defaultsStore,
    );

    final first = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/portrait.jpg',
      sourceUrl: 'https://cdn.example.com/portrait.jpg',
      pixelWidth: 400,
      pixelHeight: 800,
    );
    final second = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/retry.jpg',
      sourceUrl: 'https://cdn.example.com/portrait.jpg',
      pixelWidth: 1200,
      pixelHeight: 600,
    );
    final definition = await service.ensureDefinition(workspaceId);
    final stored = (await objectStore.listObjects(definition.objectType.id)).single;
    final defaults = await defaultsStore.read(definition.objectType.id);

    expect(second.id, first.id);
    expect(definition.pixelWidthProperty.type, ObjectPropertyType.number);
    expect(definition.pixelHeightProperty.type, ObjectPropertyType.number);
    expect(stored.values[definition.pixelWidthProperty.id], 400);
    expect(stored.values[definition.pixelHeightProperty.id], 800);
    expect(definition.aspectRatioFor(stored), .5);
    expect(defaults?.visiblePropertyIds, isNot(contains(definition.pixelWidthProperty.id)));
    expect(defaults?.visiblePropertyIds, isNot(contains(definition.pixelHeightProperty.id)));
  });

  test('managed Image rejects non-positive dimensions before mutation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );

    await expectLater(
      service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/bad.jpg',
        pixelWidth: 0,
        pixelHeight: 20,
      ),
      throwsArgumentError,
    );
    final definition = await service.ensureDefinition(workspaceId);
    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
  });
}
