import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const digestA =
      'ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789';
  const digestB =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  test('canonical File stores normalized optional SHA-256 metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final service = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);

    final object = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/report.pdf',
      sha256: digestA,
    );

    expect(
      object.values[definition.sha256Property.id],
      digestA.toLowerCase(),
    );
    expect(definition.sha256Property.config['system'], isTrue);
  });

  test('same-path reimport backfills hash once and preserves existing metadata',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: ObjectStore(genericStore),
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);

    final first = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/report.pdf',
    );
    final backfilled = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/report.pdf',
      sha256: digestA,
    );
    final preserved = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/report.pdf',
      sha256: digestB,
    );

    expect(backfilled.id, first.id);
    expect(preserved.id, first.id);
    expect(
      preserved.values[definition.sha256Property.id],
      digestA.toLowerCase(),
    );
  });

  test('equal hashes do not merge independently managed File identities', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: ObjectStore(genericStore),
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );

    final first = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/a.bin',
      sha256: digestB,
    );
    final second = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/b.bin',
      sha256: digestB,
    );

    expect(second.id, isNot(first.id));
  });

  test('invalid SHA-256 is rejected before File Object mutation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await service.ensureDefinition(workspaceId);

    await expectLater(
      service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/report.pdf',
        sha256: 'not-a-sha256',
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(await objectStore.listObjects(definition.objectType.id), isEmpty);
  });

  test('generated pre-hash File order upgrades without changing visibility',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: ObjectStore(genericStore),
      ),
      defaultsStore: defaultsStore,
    );
    final definition = await service.ensureDefinition(workspaceId);
    final previousVisible = <int>[
      definition.originalFilenameProperty.id,
      definition.contentTypeProperty.id,
      definition.extensionProperty.id,
      definition.sizeBytesProperty.id,
      definition.importedAtProperty.id,
    ];
    final previousOrder = <int>[
      ...previousVisible,
      definition.fileProperty.id,
    ];
    await defaultsStore.write(
      objectTypeId: definition.objectType.id,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: previousVisible,
        propertyOrder: previousOrder,
        openMode: ObjectOpenMode.sidePeek,
      ),
    );

    await service.ensureDefinition(workspaceId);
    final upgraded = await defaultsStore.read(definition.objectType.id);

    expect(upgraded?.visiblePropertyIds, previousVisible);
    expect(upgraded?.propertyOrder, <int>[
      ...previousVisible,
      definition.sha256Property.id,
      definition.fileProperty.id,
    ]);
  });

  test('custom File property order is preserved when SHA-256 is provisioned',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final service = FileObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: ObjectStore(genericStore),
      ),
      defaultsStore: defaultsStore,
    );
    final definition = await service.ensureDefinition(workspaceId);
    final customOrder = <int>[
      definition.fileProperty.id,
      definition.originalFilenameProperty.id,
      definition.contentTypeProperty.id,
    ];
    await defaultsStore.write(
      objectTypeId: definition.objectType.id,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[definition.originalFilenameProperty.id],
        propertyOrder: customOrder,
        openMode: ObjectOpenMode.fullPage,
      ),
    );

    await service.ensureDefinition(workspaceId);
    final preserved = await defaultsStore.read(definition.objectType.id);

    expect(preserved?.propertyOrder, customOrder);
    expect(preserved?.visiblePropertyIds, <int>[
      definition.originalFilenameProperty.id,
    ]);
    expect(preserved?.openMode, ObjectOpenMode.fullPage);
  });
}
