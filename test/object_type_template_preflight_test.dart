import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('later unknown primitive fails before provisioning an earlier target',
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
    final templates = ObjectTypeTemplateStore(genericStore);
    const invalid = ObjectTypeTemplate(
      key: 'unknown-primitive-preflight',
      name: 'Invalid primitive template',
      icon: 'X',
      description: 'must fail before provisioning',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Cover',
          type: 'relation',
          relationTargetSystemKey: ImageObjectService.systemKey,
        ),
        ObjectTypeTemplateProperty(
          name: 'Missing',
          type: 'relation',
          relationTargetSystemKey: 'missing-primitive',
        ),
      ],
    );

    final before = await genericStore.listAllDatabases(workspaceId);
    expect(
      await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
      ),
      isNull,
    );

    await expectLater(
      templates.createFromTemplate(
        workspaceId: workspaceId,
        template: invalid,
      ),
      throwsStateError,
    );

    expect(
      await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
      ),
      isNull,
    );
    expect(
      (await genericStore.listAllDatabases(workspaceId)).length,
      before.length,
    );
  });

  test('duplicate Property names fail before primitive provisioning', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final templates = ObjectTypeTemplateStore(genericStore);
    const invalid = ObjectTypeTemplate(
      key: 'duplicate-property-preflight',
      name: 'Duplicate Property template',
      icon: 'X',
      description: 'must fail before provisioning',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Cover',
          type: 'relation',
          relationTargetSystemKey: ImageObjectService.systemKey,
        ),
        ObjectTypeTemplateProperty(name: 'Cover', type: 'text'),
      ],
    );

    await expectLater(
      templates.createFromTemplate(
        workspaceId: workspaceId,
        template: invalid,
      ),
      throwsStateError,
    );

    expect(
      await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
      ),
      isNull,
    );
  });

  test('unknown Property type fails instead of silently becoming text',
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
    final templates = ObjectTypeTemplateStore(genericStore);
    const invalid = ObjectTypeTemplate(
      key: 'unknown-property-type-preflight',
      name: 'Unknown Property type template',
      icon: 'X',
      description: 'must not coerce an unknown type to text',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Cover',
          type: 'relation',
          relationTargetSystemKey: ImageObjectService.systemKey,
        ),
        ObjectTypeTemplateProperty(name: 'Typo', type: 'texxt'),
      ],
    );

    await expectLater(
      templates.createFromTemplate(
        workspaceId: workspaceId,
        template: invalid,
      ),
      throwsStateError,
    );

    expect(
      await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
      ),
      isNull,
    );
    expect(
      (await genericStore.listAllDatabases(workspaceId))
          .where((database) => database.name == invalid.name),
      isEmpty,
    );
  });

  test('invalid View Property reference fails before primitive provisioning',
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
    final templates = ObjectTypeTemplateStore(genericStore);
    const invalid = ObjectTypeTemplate(
      key: 'view-reference-preflight',
      name: 'Invalid View reference template',
      icon: 'X',
      description: 'must fail before provisioning',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Cover',
          type: 'relation',
          relationTargetSystemKey: ImageObjectService.systemKey,
        ),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Gallery',
          layoutType: 'gallery',
          visiblePropertyNames: ['Missing'],
        ),
      ],
    );

    await expectLater(
      templates.createFromTemplate(
        workspaceId: workspaceId,
        template: invalid,
      ),
      throwsStateError,
    );

    expect(
      await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
      ),
      isNull,
    );
  });
}
