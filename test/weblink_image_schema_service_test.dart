import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Weblink Image schema is idempotent with canonical cardinality', () async {
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
    final service = WeblinkImageSchemaService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );

    final first = await service.ensureDefinition(workspaceId);
    final second = await service.ensureDefinition(workspaceId);

    expect(second.weblinkObjectTypeId, first.weblinkObjectTypeId);
    expect(second.imageObjectTypeId, first.imageObjectTypeId);
    expect(
      second.representativeImageProperty.id,
      first.representativeImageProperty.id,
    );
    expect(second.relatedImagesProperty.id, first.relatedImagesProperty.id);

    expect(first.representativeImageProperty.isRelation, isTrue);
    expect(
      first.representativeImageProperty.targetObjectTypeId,
      first.imageObjectTypeId,
    );
    expect(first.representativeImageProperty.allowsMultipleRelations, isFalse);
    expect(first.relatedImagesProperty.isRelation, isTrue);
    expect(
      first.relatedImagesProperty.targetObjectTypeId,
      first.imageObjectTypeId,
    );
    expect(first.relatedImagesProperty.allowsMultipleRelations, isTrue);

    final weblinkType = await objectStore.getObjectType(first.weblinkObjectTypeId);
    expect(
      weblinkType!.properties.where(
        (property) =>
            property.name == WeblinkImageSchemaService.representativeImageName,
      ),
      hasLength(1),
    );
    expect(
      weblinkType.properties.where(
        (property) => property.name == WeblinkImageSchemaService.relatedImagesName,
      ),
      hasLength(1),
    );
  });

  test('Weblink Image schema fails closed on conflicting system property',
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
    final weblink = await WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);
    await systemObjects.ensureProperty(
      objectTypeId: weblink.objectType.id,
      name: WeblinkImageSchemaService.representativeImageName,
      type: ObjectPropertyType.text,
    );

    final service = WeblinkImageSchemaService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    await expectLater(
      service.ensureDefinition(workspaceId),
      throwsStateError,
    );
  });
}
