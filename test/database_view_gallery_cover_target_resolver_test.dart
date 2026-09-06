import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_gallery_cover_target_resolver.dart';
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
  late AppDatabase database;
  late int workspaceId;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late SystemObjectStore systemObjects;
  late AppObjectType imageType;
  late AppObjectType weblinkType;
  late DatabaseViewGalleryCoverTargetResolver resolver;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    imageType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: ImageObjectService.systemKey,
      name: 'Image',
      icon: '🖼️',
    );
    weblinkType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: WeblinkObjectService.systemKey,
      name: 'Weblink',
      icon: '🔗',
    );
    resolver = DatabaseViewGalleryCoverTargetResolver(
      objectStore: objectStore,
      systemObjects: systemObjects,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('direct Image source resolves only a canonical Image Object', () async {
    final imageId = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Cover',
    );

    expect(
      await resolver.resolve(
        sourceObjectTypeId: imageType.id,
        sourceObjectId: imageId,
        source: const GalleryCoverSource.directImage(),
      ),
      GalleryCoverTarget(
        kind: GalleryCoverTargetKind.image,
        objectTypeId: imageType.id,
        objectId: imageId,
      ),
    );
  });

  test('multi Image Relation chooses first persisted position deterministically',
      () async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Images',
      targetObjectTypeId: imageType.id,
      multiple: true,
    );
    final source = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book A',
    );
    final first = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'First',
    );
    final second = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Second',
    );
    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .firstWhere((item) => item.id == relationId);
    await objectStore.setRelation(
      objectId: source,
      property: property,
      targetObjectIds: [second, first],
    );

    expect(
      await resolver.resolve(
        sourceObjectTypeId: sourceTypeId,
        sourceObjectId: source,
        source: GalleryCoverSource.imageRelation(relationId),
      ),
      GalleryCoverTarget(
        kind: GalleryCoverTargetKind.image,
        objectTypeId: imageType.id,
        objectId: second,
      ),
    );
  });

  test('Weblink Relation returns the canonical Weblink target Object', () async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Paper',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Source',
      targetObjectTypeId: weblinkType.id,
      multiple: false,
    );
    final source = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Paper A',
    );
    final weblink = await objectStore.createObject(
      objectTypeId: weblinkType.id,
      title: 'Reference',
    );
    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .firstWhere((item) => item.id == relationId);
    await objectStore.setRelation(
      objectId: source,
      property: property,
      targetObjectIds: [weblink],
    );

    expect(
      await resolver.resolve(
        sourceObjectTypeId: sourceTypeId,
        sourceObjectId: source,
        source: GalleryCoverSource.weblinkRelationRepresentativeImage(
          relationId,
        ),
      ),
      GalleryCoverTarget(
        kind: GalleryCoverTargetKind.weblink,
        objectTypeId: weblinkType.id,
        objectId: weblink,
      ),
    );
  });

  test('stale serialized Relation/index disagreement fails closed', () async {
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
    final source = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book A',
    );
    final image = await objectStore.createObject(
      objectTypeId: imageType.id,
      title: 'Cover',
    );

    // Deliberately bypass ObjectStore.setRelation so the normalized edge index
    // stays empty. A Gallery reader must not repair this state opportunistically.
    await genericStore.setValue(
      recordId: source,
      propertyId: relationId,
      value: ObjectRelationValue(objectIds: [image]).toJson(multiple: false),
    );

    expect(
      await resolver.resolve(
        sourceObjectTypeId: sourceTypeId,
        sourceObjectId: source,
        source: GalleryCoverSource.imageRelation(relationId),
      ),
      isNull,
    );
    expect(await objectStore.outgoingRelations(source), isEmpty);
  });

  test('configured source kind must still match Relation target system type',
      () async {
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Source',
      targetObjectTypeId: weblinkType.id,
      multiple: false,
    );
    final source = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Book A',
    );
    final weblink = await objectStore.createObject(
      objectTypeId: weblinkType.id,
      title: 'Reference',
    );
    final property = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .firstWhere((item) => item.id == relationId);
    await objectStore.setRelation(
      objectId: source,
      property: property,
      targetObjectIds: [weblink],
    );

    expect(
      await resolver.resolve(
        sourceObjectTypeId: sourceTypeId,
        sourceObjectId: source,
        source: GalleryCoverSource.imageRelation(relationId),
      ),
      isNull,
    );
  });
}
