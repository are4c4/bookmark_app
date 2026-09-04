import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Weblink definition is idempotent and exposed as navigation database',
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
    final service = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );

    final first = await service.ensureDefinition(workspaceId);
    final second = await service.ensureDefinition(workspaceId);

    expect(second.objectType.id, first.objectType.id);
    expect(first.objectType.kind, ObjectTypeKind.system);
    expect(first.urlProperty.type, ObjectPropertyType.url);
    expect(first.domainProperty.type, ObjectPropertyType.text);
    expect(first.pageTitleProperty.type, ObjectPropertyType.text);
    expect(first.descriptionProperty.type, ObjectPropertyType.text);
    expect(first.previewImageUrlProperty.type, ObjectPropertyType.url);
    for (final name in <String>[
      'URL',
      'Domain',
      'Page title',
      'Description',
      'Preview image URL',
    ]) {
      expect(
        second.objectType.properties.where((property) => property.name == name),
        hasLength(1),
      );
    }
    final navigation = await genericStore.listDatabases(workspaceId);
    expect(navigation, hasLength(1));
    expect(navigation.single.id, first.objectType.id);
    expect(navigation.single.name, 'Weblinks');
    expect(navigation.single.icon, '🔗');

    final defaults = await defaultsStore.read(first.objectType.id);
    expect(
      defaults?.visiblePropertyIds,
      <int>[
        first.urlProperty.id,
        first.domainProperty.id,
        first.pageTitleProperty.id,
        first.descriptionProperty.id,
      ],
    );
    expect(defaults?.openMode, ObjectOpenMode.sidePeek);
  });

  test('definition upgrades URL-only defaults but preserves customized lists',
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
      systemKey: WeblinkObjectService.systemKey,
      name: 'Weblink',
      icon: '🔗',
    );
    final legacyUrl = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'URL',
      type: ObjectPropertyType.url,
    );
    await defaultsStore.write(
      objectTypeId: type.id,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[legacyUrl.id],
        propertyOrder: <int>[legacyUrl.id],
        openMode: ObjectOpenMode.sidePeek,
      ),
    );

    final service = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final definition = await service.ensureDefinition(workspaceId);
    final upgraded = await defaultsStore.read(type.id);
    expect(
      upgraded?.visiblePropertyIds,
      <int>[
        definition.urlProperty.id,
        definition.domainProperty.id,
        definition.pageTitleProperty.id,
        definition.descriptionProperty.id,
      ],
    );
    expect(
      upgraded?.propertyOrder,
      <int>[
        definition.urlProperty.id,
        definition.domainProperty.id,
        definition.pageTitleProperty.id,
        definition.descriptionProperty.id,
        definition.previewImageUrlProperty.id,
      ],
    );

    final customVisible = <int>[
      definition.urlProperty.id,
      definition.previewImageUrlProperty.id,
    ];
    final customOrder = <int>[
      definition.previewImageUrlProperty.id,
      definition.urlProperty.id,
    ];
    await defaultsStore.write(
      objectTypeId: type.id,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: customVisible,
        propertyOrder: customOrder,
        openMode: ObjectOpenMode.fullPage,
      ),
    );

    await service.ensureDefinition(workspaceId);
    final preserved = await defaultsStore.read(type.id);
    expect(preserved?.visiblePropertyIds, customVisible);
    expect(preserved?.propertyOrder, customOrder);
    expect(preserved?.openMode, ObjectOpenMode.fullPage);
  });

  test('normalization canonicalizes safe URL components only', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: ObjectStore(genericStore),
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );

    expect(
      service.normalizeUrl(' HTTPS://Example.COM:443 '),
      'https://example.com/',
    );
    expect(
      service.normalizeUrl(
        'https://Example.com/a/../article?b=2&a=1#section',
      ),
      'https://example.com/article?b=2&a=1#section',
    );
    expect(
      service.normalizeUrl('http://Example.com:8080/path'),
      'http://example.com:8080/path',
    );
    expect(
      () => service.normalizeUrl('example.com/no-scheme'),
      throwsArgumentError,
    );
  });

  test('findOrCreate reuses Weblinks across normalized URL variants', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );

    final first = await service.findOrCreate(
      workspaceId: workspaceId,
      url: 'HTTPS://Example.COM:443/a/../article?x=1#part',
    );
    final second = await service.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/article?x=1#part',
      title: 'Different requested title',
    );
    final definition = await service.ensureDefinition(workspaceId);

    expect(second.id, first.id);
    expect(first.title, 'example.com');
    expect(
      first.values[definition.urlProperty.id],
      'https://example.com/article?x=1#part',
    );
    expect(first.values[definition.domainProperty.id], 'example.com');
    expect(
      (await objectStore.listObjects(definition.objectType.id)).length,
      1,
    );
  });

  test('enrichment seeds Weblink metadata once without later overwrite', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final weblink = await service.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://Example.com/article',
    );
    final definition = await service.ensureDefinition(workspaceId);

    final enriched = await service.enrichIfMissing(
      workspaceId: workspaceId,
      objectId: weblink.id,
      pageTitle: '  Resource title  ',
      description: '  Resource description  ',
      previewImageUrl: 'HTTPS://CDN.Example.com:443/a/../preview.jpg?sig=1',
    );

    expect(enriched.title, 'example.com');
    expect(enriched.values[definition.domainProperty.id], 'example.com');
    expect(enriched.values[definition.pageTitleProperty.id], 'Resource title');
    expect(
      enriched.values[definition.descriptionProperty.id],
      'Resource description',
    );
    expect(
      enriched.values[definition.previewImageUrlProperty.id],
      'https://cdn.example.com/preview.jpg?sig=1',
    );

    final preserved = await service.enrichIfMissing(
      workspaceId: workspaceId,
      objectId: weblink.id,
      pageTitle: 'Bookmark-specific later title',
      description: 'Bookmark-specific later description',
      previewImageUrl: 'https://cdn.example.com/other.jpg',
    );
    expect(preserved.values[definition.pageTitleProperty.id], 'Resource title');
    expect(
      preserved.values[definition.descriptionProperty.id],
      'Resource description',
    );
    expect(
      preserved.values[definition.previewImageUrlProperty.id],
      'https://cdn.example.com/preview.jpg?sig=1',
    );
  });

  test('invalid preview metadata is ignored without blocking Weblink enrichment',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final weblink = await service.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.org/article',
    );
    final definition = await service.ensureDefinition(workspaceId);

    final enriched = await service.enrichIfMissing(
      workspaceId: workspaceId,
      objectId: weblink.id,
      pageTitle: 'Valid title',
      previewImageUrl: 'not an absolute URL',
    );

    expect(enriched.values[definition.pageTitleProperty.id], 'Valid title');
    expect(enriched.values[definition.previewImageUrlProperty.id], isNull);
  });

  test('normalization preserves query and fragment distinctions', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );

    await service.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/article?a=1#first',
    );
    await service.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/article?a=2#first',
    );
    await service.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/article?a=1#second',
    );
    final definition = await service.ensureDefinition(workspaceId);

    expect(await objectStore.listObjects(definition.objectType.id), hasLength(3));
  });

  test('URL Value can produce a non-destructive Weblink promotion plan', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: defaultsStore,
    );
    final target = await service.ensureDefinition(workspaceId);
    const source = ObjectPropertyDefinition(
      id: 99,
      objectTypeId: 42,
      name: 'Website',
      type: ObjectPropertyType.url,
      sortOrder: 0,
    );

    final plan = service.planUrlPromotion(
      sourceProperty: source,
      sourceValue: 'https://example.com/article',
      target: target,
    );

    expect(plan.targetObjectTypeId, target.objectType.id);
    expect(plan.targetObjectTitle, 'example.com');
    expect(plan.sourceValue, 'https://example.com/article');
    expect(plan.preservesSourceValue, isTrue);
    expect(plan.requiresDestructiveConfirmation, isFalse);
  });

  test('Weblink promotion rejects non-URL Value properties', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: defaultsStore,
    );
    final target = await service.ensureDefinition(workspaceId);
    const source = ObjectPropertyDefinition(
      id: 99,
      objectTypeId: 42,
      name: 'Website',
      type: ObjectPropertyType.text,
      sortOrder: 0,
    );

    expect(
      () => service.planUrlPromotion(
        sourceProperty: source,
        sourceValue: 'https://example.com',
        target: target,
      ),
      throwsArgumentError,
    );
  });
}
