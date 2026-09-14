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
  test(
    'Image definition hides new and historical native storage metadata',
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
      final imageType = await systemObjects.ensureSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
        name: '画像',
        icon: '🖼️',
      );
      final historicalFile = await systemObjects.ensureProperty(
        objectTypeId: imageType.id,
        name: 'File',
        type: ObjectPropertyType.file,
        config: const <String, dynamic>{'system': true, 'legacy': 'preserve'},
      );
      final historicalOwnership = await systemObjects.ensureProperty(
        objectTypeId: imageType.id,
        name: 'Storage ownership',
        type: ObjectPropertyType.text,
        config: const <String, dynamic>{'system': true},
      );

      final definition = await ImageObjectService(
        systemObjects: systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      ).ensureDefinition(workspaceId);

      expect(definition.fileProperty.id, historicalFile.id);
      expect(definition.fileProperty.config['system'], isTrue);
      expect(definition.fileProperty.config['hidden'], isTrue);
      expect(definition.fileProperty.config['legacy'], 'preserve');
      expect(definition.storageOwnershipProperty.id, historicalOwnership.id);
      expect(definition.storageOwnershipProperty.config['system'], isTrue);
      expect(definition.storageOwnershipProperty.config['hidden'], isTrue);
    },
  );

  test(
    'Image visibility upgrade does not claim a user-owned File Property',
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
      final imageType = await systemObjects.ensureSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
        name: '画像',
        icon: '🖼️',
      );
      final conflicting = await systemObjects.ensureProperty(
        objectTypeId: imageType.id,
        name: 'File',
        type: ObjectPropertyType.file,
        config: const <String, dynamic>{'userOwned': true},
      );

      final service = ImageObjectService(
        systemObjects: systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );

      await expectLater(service.ensureDefinition(workspaceId), throwsStateError);

      final reloaded = await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
      );
      final preserved = reloaded!.properties.singleWhere(
        (property) => property.id == conflicting.id,
      );
      expect(preserved.type, ObjectPropertyType.file);
      expect(preserved.config, const <String, dynamic>{'userOwned': true});
      expect(preserved.config['system'], isNull);
      expect(preserved.config['hidden'], isNull);
    },
  );

  test(
    'Image visibility upgrade does not rewrite a wrong-type system File',
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
      final imageType = await systemObjects.ensureSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
        name: '画像',
        icon: '🖼️',
      );
      final conflicting = await systemObjects.ensureProperty(
        objectTypeId: imageType.id,
        name: 'File',
        type: ObjectPropertyType.text,
        config: const <String, dynamic>{'system': true, 'legacy': 'preserve'},
      );

      final service = ImageObjectService(
        systemObjects: systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );

      await expectLater(service.ensureDefinition(workspaceId), throwsStateError);

      final reloaded = await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
      );
      final preserved = reloaded!.properties.singleWhere(
        (property) => property.id == conflicting.id,
      );
      expect(preserved.type, ObjectPropertyType.text);
      expect(
        preserved.config,
        const <String, dynamic>{'system': true, 'legacy': 'preserve'},
      );
      expect(preserved.config['hidden'], isNull);
    },
  );
}
