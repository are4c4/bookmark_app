import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_target_quick_create_policy.dart';
import 'package:bookmark_app/data/relation_target_quick_create_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late int workspaceId;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late SystemObjectStore systemObjects;
  late ObjectTypeDefaultsStore defaults;
  late TagObjectBridge tagBridge;
  late WeblinkObjectService weblinks;
  late RelationTargetQuickCreatePolicy policy;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    defaults = ObjectTypeDefaultsStore(genericStore);
    tagBridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjects,
    );
    weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    );
    policy = RelationTargetQuickCreatePolicy(
      objectStore: objectStore,
      systemObjects: systemObjects,
    );
  });

  tearDown(() async {
    await database.close();
  });

  RelationTargetQuickCreateService service({
    RelationQuickCreateWeblinkEnricher? enrich,
  }) =>
      RelationTargetQuickCreateService(
        policy: policy,
        objectStore: objectStore,
        tagBridge: tagBridge,
        weblinks: weblinks,
        weblinkEnricher: enrich,
      );

  test('custom Relation target uses normal Object creation', () async {
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Author',
    );

    final created = await service().create(
      workspaceId: workspaceId,
      targetObjectTypeId: targetTypeId,
      input: '  Ada Lovelace  ',
    );

    expect(created, isNotNull);
    expect(created!.objectTypeId, targetTypeId);
    expect(created.title, 'Ada Lovelace');
    expect(await objectStore.listObjects(targetTypeId), hasLength(1));
  });

  test('Tag quick-create creates legacy Tag and canonical Tag Object together', () async {
    final schema = await tagBridge.ensureTagObjectType(workspaceId);

    final created = await service().create(
      workspaceId: workspaceId,
      targetObjectTypeId: schema.objectType.id,
      input: '  Algebra  ',
    );

    expect(created, isNotNull);
    expect(created!.objectTypeId, schema.objectType.id);
    expect(created.title, 'Algebra');
    final legacyTagId = await tagBridge.legacyTagIdForObject(
      workspaceId,
      created.id,
    );
    expect(legacyTagId, isNotNull);
    expect(
      await tagBridge.objectIdForLegacyTag(workspaceId, legacyTagId!),
      created.id,
    );
  });

  test('Weblink quick-create uses canonical URL identity and enrichment is fail-soft', () async {
    final definition = await weblinks.ensureDefinition(workspaceId);
    var enrichCalls = 0;
    final quickCreate = service(
      enrich: ({required workspaceId, required objectId, required url}) async {
        enrichCalls++;
        throw StateError('optional metadata failure');
      },
    );

    final first = await quickCreate.create(
      workspaceId: workspaceId,
      targetObjectTypeId: definition.objectType.id,
      input: ' https://example.com/path ',
    );
    final second = await quickCreate.create(
      workspaceId: workspaceId,
      targetObjectTypeId: definition.objectType.id,
      input: 'HTTPS://EXAMPLE.COM:443/path',
    );

    expect(first, isNotNull);
    expect(second?.id, first!.id);
    expect(enrichCalls, 2);
    expect(
      (await objectStore.listObjects(definition.objectType.id)),
      hasLength(1),
    );
  });

  test('Weblink quick-create fails closed on canonical collision before enrichment', () async {
    final definition = await weblinks.ensureDefinition(workspaceId);
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Source URL',
      targetObjectTypeId: definition.objectType.id,
      multiple: false,
    );
    final sourceRelation =
        (await objectStore.getObjectType(sourceTypeId))!.properties.single;
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source',
    );

    await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/article',
      title: 'First canonical candidate',
    );
    final duplicateId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Second canonical candidate',
    );
    await objectStore.setPropertyValue(
      objectId: duplicateId,
      property: definition.urlProperty,
      value: 'HTTPS://EXAMPLE.COM:443/article',
    );
    var enrichCalls = 0;

    await expectLater(
      service(
        enrich:
            ({required workspaceId, required objectId, required url}) async {
              enrichCalls++;
            },
      ).create(
        workspaceId: workspaceId,
        targetObjectTypeId: definition.objectType.id,
        input: 'https://example.com/article',
      ),
      throwsA(isA<StateError>()),
    );

    expect(enrichCalls, 0);
    expect(
      await objectStore.listObjects(definition.objectType.id),
      hasLength(2),
    );
    final sourceAfter = (await objectStore.listObjects(sourceTypeId)).single;
    expect(sourceAfter.values[sourceRelation.id], isNull);
    expect(await objectStore.outgoingRelations(sourceId), isEmpty);
  });

  test('Image quick-create requires managed import callback and validates result type', () async {
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    );
    final definition = await images.ensureDefinition(workspaceId);
    final quickCreate = service();

    await expectLater(
      quickCreate.create(
        workspaceId: workspaceId,
        targetObjectTypeId: definition.objectType.id,
      ),
      throwsStateError,
    );

    final created = await quickCreate.create(
      workspaceId: workspaceId,
      targetObjectTypeId: definition.objectType.id,
      createManagedImage: () async =>
          (await images.findOrCreateManaged(
            workspaceId: workspaceId,
            filePath: '/managed/photo.png',
            originalFilename: 'photo.png',
            contentType: 'image/png',
          ))
              .id,
    );
    expect(created, isNotNull);
    expect(created!.objectTypeId, definition.objectType.id);

    final wrongTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Wrong',
    );
    final wrongObjectId = await objectStore.createObject(
      objectTypeId: wrongTypeId,
      title: 'Wrong',
    );
    await expectLater(
      quickCreate.create(
        workspaceId: workspaceId,
        targetObjectTypeId: definition.objectType.id,
        createManagedImage: () async => wrongObjectId,
      ),
      throwsStateError,
    );
  });

  test('File quick-create requires managed import callback and supports cancel', () async {
    final files = FileObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaults,
    );
    final definition = await files.ensureDefinition(workspaceId);
    final quickCreate = service();

    await expectLater(
      quickCreate.create(
        workspaceId: workspaceId,
        targetObjectTypeId: definition.objectType.id,
      ),
      throwsStateError,
    );

    final cancelled = await quickCreate.create(
      workspaceId: workspaceId,
      targetObjectTypeId: definition.objectType.id,
      createManagedFile: () async => null,
    );
    expect(cancelled, isNull);

    final created = await quickCreate.create(
      workspaceId: workspaceId,
      targetObjectTypeId: definition.objectType.id,
      createManagedFile: () async =>
          (await files.findOrCreateManaged(
            workspaceId: workspaceId,
            filePath: '/managed/paper.pdf',
            originalFilename: 'paper.pdf',
            contentType: 'application/pdf',
            sizeBytes: 42,
          ))
              .id,
    );
    expect(created, isNotNull);
    expect(created!.objectTypeId, definition.objectType.id);
  });

  test('unsupported system ObjectType cannot fall back to title-only creation', () async {
    final systemType = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'unsupported-quick-create',
      name: 'System',
      icon: '⚙️',
    );

    await expectLater(
      service().create(
        workspaceId: workspaceId,
        targetObjectTypeId: systemType.id,
        input: 'Should not be created',
      ),
      throwsUnsupportedError,
    );
    expect(await objectStore.listObjects(systemType.id), isEmpty);
  });
}
