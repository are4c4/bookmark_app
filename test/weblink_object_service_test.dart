import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Weblink definition is idempotent and hidden from custom databases', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final service = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );

    final first = await service.ensureDefinition(workspaceId);
    final second = await service.ensureDefinition(workspaceId);

    expect(second.objectType.id, first.objectType.id);
    expect(first.objectType.kind, ObjectTypeKind.system);
    expect(first.urlProperty.type, ObjectPropertyType.url);
    expect(
      second.objectType.properties
          .where((property) => property.name == 'URL')
          .length,
      1,
    );
    expect(await genericStore.listDatabases(workspaceId), isEmpty);

    final defaults = await defaultsStore.read(first.objectType.id);
    expect(defaults?.visiblePropertyIds, <int>[first.urlProperty.id]);
    expect(defaults?.openMode, ObjectOpenMode.sidePeek);
  });

  test('URL Value can produce a non-destructive Weblink promotion plan', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: defaultsStore,
    );
    final target = await service.ensureDefinition(workspaceId);
    const source = ObjectPropertyDefinition(
      id: 99,
      objectTypeId: 42,
      name: 'Website',
      type: ObjectPropertyType.url,
      sortOrder: 0,
    );

    final plan = service.planUrlPromotion(
      sourceProperty: source,
      sourceValue: 'https://example.com/article',
      target: target,
    );

    expect(plan.targetObjectTypeId, target.objectType.id);
    expect(plan.targetObjectTitle, 'example.com');
    expect(plan.sourceValue, 'https://example.com/article');
    expect(plan.preservesSourceValue, isTrue);
    expect(plan.requiresDestructiveConfirmation, isFalse);
  });

  test('Weblink promotion rejects non-URL Value properties', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: defaultsStore,
    );
    final target = await service.ensureDefinition(workspaceId);
    const source = ObjectPropertyDefinition(
      id: 99,
      objectTypeId: 42,
      name: 'Website',
      type: ObjectPropertyType.text,
      sortOrder: 0,
    );

    expect(
      () => service.planUrlPromotion(
        sourceProperty: source,
        sourceValue: 'https://example.com',
        target: target,
      ),
      throwsArgumentError,
    );
  });
}
