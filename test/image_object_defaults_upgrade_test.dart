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
  test('Image definition upgrades legacy defaults but preserves customization',
      () async {
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
    final type = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: '画像',
      icon: '🖼️',
    );
    final file = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'File',
      type: ObjectPropertyType.file,
      config: const <String, dynamic>{'system': true},
    );
    final note = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Note',
      type: ObjectPropertyType.text,
    );
    await defaultsStore.write(
      objectTypeId: type.id,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[file.id, note.id],
        propertyOrder: <int>[file.id, note.id],
        openMode: ObjectOpenMode.sidePeek,
      ),
    );

    final service = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final definition = await service.ensureDefinition(workspaceId);
    final upgraded = await defaultsStore.read(type.id);
    expect(upgraded?.visiblePropertyIds, <int>[
      definition.originalFilenameProperty.id,
      definition.noteProperty.id,
      definition.contentTypeProperty.id,
      definition.sourceUrlProperty.id,
    ]);
    expect(upgraded?.propertyOrder, <int>[
      definition.originalFilenameProperty.id,
      definition.noteProperty.id,
      definition.contentTypeProperty.id,
      definition.sourceUrlProperty.id,
      definition.fileProperty.id,
    ]);

    final customOrder = <int>[
      definition.sourceUrlProperty.id,
      definition.fileProperty.id,
    ];
    await defaultsStore.write(
      objectTypeId: type.id,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[definition.sourceUrlProperty.id],
        propertyOrder: customOrder,
        openMode: ObjectOpenMode.fullPage,
      ),
    );
    await service.ensureDefinition(workspaceId);
    final preserved = await defaultsStore.read(type.id);
    expect(
      preserved?.visiblePropertyIds,
      <int>[definition.sourceUrlProperty.id],
    );
    expect(preserved?.propertyOrder, customOrder);
    expect(preserved?.openMode, ObjectOpenMode.fullPage);
  });

  test('Image definition upgrades the previous expanded default order', () async {
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
    final definition = await service.ensureDefinition(workspaceId);

    await defaultsStore.write(
      objectTypeId: definition.objectType.id,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[
          definition.fileProperty.id,
          definition.noteProperty.id,
        ],
        propertyOrder: <int>[
          definition.fileProperty.id,
          definition.noteProperty.id,
          definition.sourceUrlProperty.id,
          definition.originalFilenameProperty.id,
          definition.contentTypeProperty.id,
        ],
        openMode: ObjectOpenMode.sidePeek,
      ),
    );

    await service.ensureDefinition(workspaceId);
    final upgraded = await defaultsStore.read(definition.objectType.id);
    expect(upgraded?.visiblePropertyIds, <int>[
      definition.originalFilenameProperty.id,
      definition.noteProperty.id,
      definition.contentTypeProperty.id,
      definition.sourceUrlProperty.id,
    ]);
    expect(upgraded?.propertyOrder, <int>[
      definition.originalFilenameProperty.id,
      definition.noteProperty.id,
      definition.contentTypeProperty.id,
      definition.sourceUrlProperty.id,
      definition.fileProperty.id,
    ]);
  });
}
