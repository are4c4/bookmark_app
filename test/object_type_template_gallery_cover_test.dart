import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Plant template stores its created Image Relation as Gallery cover source',
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
    await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: TagObjectBridge.systemKey,
      name: 'Tag',
      icon: '🏷️',
    );

    final templateStore = ObjectTypeTemplateStore(genericStore);
    final plant = templateStore.templateByKey('plant')!;
    final plantTypeId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: plant,
    );

    final plantType = (await objectStore.getObjectType(plantTypeId))!;
    final photoRelation = plantType.properties.singleWhere(
      (property) => property.name == '写真',
    );
    final views = await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: 'custom:$plantTypeId',
    );

    expect(views, hasLength(1));
    expect(views.single.layoutType, 'gallery');
    expect(
      const DatabaseViewGalleryAdapter().decodeCoverSource(views.single),
      GalleryCoverSource.imageRelation(photoRelation.id),
    );
  });

  test('invalid symbolic Gallery cover reference rolls template creation back',
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
    await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    final templateStore = ObjectTypeTemplateStore(genericStore);

    const invalid = ObjectTypeTemplate(
      key: 'invalid-cover-test',
      name: 'Invalid',
      icon: 'X',
      description: 'test',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Cover',
          type: 'relation',
          relationTargetSystemKey: ImageObjectService.systemKey,
          relationMultiple: false,
        ),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Gallery',
          layoutType: 'gallery',
          galleryCoverRelationPropertyName: 'Missing',
          galleryCoverKind: ObjectTypeTemplateGalleryCoverKind.imageRelation,
        ),
      ],
    );

    await expectLater(
      templateStore.createFromTemplate(
        workspaceId: workspaceId,
        template: invalid,
      ),
      throwsStateError,
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    expect(types.where((type) => type.name == 'Invalid'), isEmpty);
    expect(
      await DatabaseViewStore(database).listViews(
        workspaceId: workspaceId,
        databaseKey: 'custom:999999',
      ),
      isEmpty,
    );
  });

  test('Gallery cover kind must match the Relation target primitive', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: TagObjectBridge.systemKey,
      name: 'Tag',
      icon: '🏷️',
    );
    final templateStore = ObjectTypeTemplateStore(genericStore);

    const invalid = ObjectTypeTemplate(
      key: 'mismatched-cover-target-test',
      name: 'Mismatched cover target',
      icon: 'X',
      description: 'test',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Tags',
          type: 'relation',
          relationTargetSystemKey: TagObjectBridge.systemKey,
          relationMultiple: true,
        ),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Gallery',
          layoutType: 'gallery',
          galleryCoverRelationPropertyName: 'Tags',
          galleryCoverKind: ObjectTypeTemplateGalleryCoverKind.imageRelation,
        ),
      ],
    );

    await expectLater(
      templateStore.createFromTemplate(
        workspaceId: workspaceId,
        template: invalid,
      ),
      throwsStateError,
    );

    final types = await objectStore.listObjectTypes(workspaceId);
    expect(
      types.where((type) => type.name == 'Mismatched cover target'),
      isEmpty,
    );
  });
}
