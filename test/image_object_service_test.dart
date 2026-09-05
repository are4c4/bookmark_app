import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Image definition reuses system image type and installs defaults', () async {
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
    final service = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );

    final first = await service.ensureDefinition(workspaceId);
    final second = await service.ensureDefinition(workspaceId);

    expect(second.objectType.id, first.objectType.id);
    expect(first.objectType.kind, ObjectTypeKind.system);
    expect(first.fileProperty.type, ObjectPropertyType.file);
    expect(first.noteProperty.type, ObjectPropertyType.text);
    expect(first.sourceUrlProperty.type, ObjectPropertyType.url);
    expect(first.originalFilenameProperty.type, ObjectPropertyType.text);
    expect(first.contentTypeProperty.type, ObjectPropertyType.text);
    for (final name in <String>[
      'File',
      'Note',
      'Source URL',
      'Original filename',
      'Content type',
    ]) {
      expect(
        second.objectType.properties.where((property) => property.name == name),
        hasLength(1),
      );
    }
    final defaults = await defaultsStore.read(first.objectType.id);
    expect(defaults?.visiblePropertyIds, <int>[
      first.originalFilenameProperty.id,
      first.noteProperty.id,
      first.contentTypeProperty.id,
      first.sourceUrlProperty.id,
    ]);
    expect(defaults?.propertyOrder, <int>[
      first.originalFilenameProperty.id,
      first.noteProperty.id,
      first.contentTypeProperty.id,
      first.sourceUrlProperty.id,
      first.fileProperty.id,
    ]);
    expect(defaults?.openMode, ObjectOpenMode.sidePeek);
  });

  test('managed Image reuses source URL and preserves canonical file metadata',
      () async {
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

    final first = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/preview.jpg',
      sourceUrl: 'https://cdn.example.com/preview.jpg?sig=1',
      originalFilename: 'preview.jpg',
      contentType: 'image/jpeg',
    );
    final second = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/later.jpg',
      sourceUrl: 'https://cdn.example.com/preview.jpg?sig=1',
      title: 'Later title',
      originalFilename: 'later.jpg',
      contentType: 'image/webp',
    );
    final definition = await service.ensureDefinition(workspaceId);

    expect(second.id, first.id);
    expect(first.title, 'preview.jpg');
    final stored = (await objectStore.listObjects(definition.objectType.id)).single;
    expect(stored.values[definition.fileProperty.id], '/managed/preview.jpg');
    expect(
      stored.values[definition.sourceUrlProperty.id],
      'https://cdn.example.com/preview.jpg?sig=1',
    );
    expect(
      stored.values[definition.originalFilenameProperty.id],
      'preview.jpg',
    );
    expect(stored.values[definition.contentTypeProperty.id], 'image/jpeg');
  });

  test('managed Image falls back to file identity and rejects invalid inputs',
      () async {
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

    final first = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/local.png',
    );
    final second = await service.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: ' /managed/local.png ',
      title: 'Ignored later title',
    );
    expect(second.id, first.id);
    expect(first.title, 'local.png');

    await expectLater(
      service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '   ',
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/bad.jpg',
        sourceUrl: 'not an absolute URL',
      ),
      throwsArgumentError,
    );
  });
}
