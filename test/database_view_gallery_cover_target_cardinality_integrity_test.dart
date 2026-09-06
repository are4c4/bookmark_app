import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_gallery_cover_target_resolver.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'single Gallery Relation fails closed when matching value and index both contain multiple targets',
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
      name: 'Image',
      icon: '🖼️',
    );
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Cover',
      targetObjectTypeId: imageType.id,
      multiple: false,
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book A',
    );
    final firstImageId = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'First',
    );
    final secondImageId = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Second',
    );

    // Simulate persisted corruption that is internally index-consistent but
    // violates the Property's single cardinality. A Gallery reader must not
    // choose one target and hide this integrity failure.
    await genericStore.setValue(
      recordId: sourceId,
      propertyId: relationId,
      value: <int>[firstImageId, secondImageId],
    );
    await objectStore.ensureRelationIndexSchema();
    await database.customStatement(
      '''INSERT INTO object_relation_edges(
           source_object_id, property_id, target_object_id, position
         ) VALUES (?, ?, ?, ?)''',
      <Object?>[sourceId, relationId, firstImageId, 0],
    );
    await database.customStatement(
      '''INSERT INTO object_relation_edges(
           source_object_id, property_id, target_object_id, position
         ) VALUES (?, ?, ?, ?)''',
      <Object?>[sourceId, relationId, secondImageId, 1],
    );

    final resolver = DatabaseViewGalleryCoverTargetResolver(
      objectStore: objectStore,
      systemObjects: systemObjects,
    );

    expect(
      await resolver.resolve(
        sourceObjectTypeId: sourceTypeId,
        sourceObjectId: sourceId,
        source: GalleryCoverSource.imageRelation(relationId),
      ),
      isNull,
    );

    // Resolution is read-only: the corrupt state stays observable for the
    // dedicated Relation integrity/reconciliation surfaces.
    expect(await objectStore.outgoingRelations(sourceId), hasLength(2));
  });
}
