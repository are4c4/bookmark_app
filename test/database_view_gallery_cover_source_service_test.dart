import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_gallery_cover_source_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discovers Image and Weblink Relation cover sources from schema', () async {
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
    final weblinkType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
      name: 'Weblink',
      icon: '🔗',
    );
    final unrelatedTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final coverPropertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Cover',
      targetObjectTypeId: imageType.id,
      multiple: false,
    );
    final linksPropertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Sources',
      targetObjectTypeId: weblinkType.id,
      multiple: true,
    );
    await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Author',
      targetObjectTypeId: unrelatedTypeId,
      multiple: true,
    );
    await objectStore.createProperty(
      objectTypeId: sourceTypeId,
      name: 'Subtitle',
      type: ObjectPropertyType.text,
    );

    final options = await DatabaseViewGalleryCoverSourceService(
      objectStore: objectStore,
      systemObjects: systemObjects,
    ).discover(objectTypeId: sourceTypeId);

    expect(
      options.map((option) => option.source),
      [
        const GalleryCoverSource.none(),
        GalleryCoverSource.imageRelation(coverPropertyId),
        GalleryCoverSource.weblinkRelationRepresentativeImage(linksPropertyId),
      ],
    );
    expect(
      options.map((option) => option.label),
      ['なし', 'Cover · Image', 'Sources · Weblinkの代表画像'],
    );
  });

  test('Image ObjectType exposes its own media as a direct cover source', () async {
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

    final options = await DatabaseViewGalleryCoverSourceService(
      objectStore: objectStore,
      systemObjects: systemObjects,
    ).discover(objectTypeId: imageType.id);

    expect(
      options.map((option) => option.source),
      const [
        GalleryCoverSource.none(),
        GalleryCoverSource.directImage(),
      ],
    );
  });
}
