import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/bookmark_metadata_service.dart';
import 'package:bookmark_app/services/weblink_create_enrichment_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Weblink resource facts are typed without changing generated defaults',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final service = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: ObjectStore(genericStore),
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );

    final definition = await service.ensureDefinition(workspaceId);
    final defaults = await ObjectTypeDefaultsStore(genericStore).read(
      definition.objectType.id,
    );

    expect(definition.contentTypeProperty.type, ObjectPropertyType.text);
    expect(definition.publishedDateProperty.type, ObjectPropertyType.date);
    expect(
      defaults?.visiblePropertyIds,
      <int>[
        definition.pageTitleProperty.id,
        definition.siteNameProperty.id,
        definition.domainProperty.id,
        definition.descriptionProperty.id,
        definition.urlProperty.id,
      ],
    );
    expect(
      defaults?.propertyOrder,
      <int>[
        definition.pageTitleProperty.id,
        definition.siteNameProperty.id,
        definition.domainProperty.id,
        definition.descriptionProperty.id,
        definition.urlProperty.id,
        definition.faviconUrlProperty.id,
        definition.previewImageUrlProperty.id,
      ],
    );
    expect(
      defaults?.visiblePropertyIds,
      isNot(contains(definition.contentTypeProperty.id)),
    );
    expect(
      defaults?.visiblePropertyIds,
      isNot(contains(definition.publishedDateProperty.id)),
    );
  });

  test('direct Weblink enrichment persists resource facts once', () async {
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
    final definition = await service.ensureDefinition(workspaceId);
    final weblink = await service.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/article',
    );
    final enrichment = WeblinkCreateEnrichmentService(
      weblinks: service,
      metadataFetch: (_) async => const BookmarkMetadata(
        url: 'https://example.com/article',
        title: 'Readable article',
        contentType: 'Text/HTML; charset=UTF-8',
        publishedDate: '2026-09-05T12:34:56+09:00',
      ),
    );

    await enrichment.enrich(
      workspaceId: workspaceId,
      objectId: weblink.id,
      url: 'https://example.com/article',
    );
    await service.enrichIfMissing(
      workspaceId: workspaceId,
      objectId: weblink.id,
      contentType: 'application/pdf',
      publishedDate: '2026-09-06',
    );

    final enriched = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == weblink.id);
    expect(enriched.values[definition.contentTypeProperty.id], 'text/html');
    expect(
      enriched.values[definition.publishedDateProperty.id],
      '2026-09-05T12:34:56+09:00',
    );
  });

  test('invalid published dates are ignored without blocking other metadata',
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
    final definition = await service.ensureDefinition(workspaceId);
    final weblink = await service.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.org/resource',
    );

    final enriched = await service.enrichIfMissing(
      workspaceId: workspaceId,
      objectId: weblink.id,
      contentType: ' Application/PDF ; version=1.7 ',
      publishedDate: 'definitely-not-a-date',
    );

    expect(enriched.values[definition.contentTypeProperty.id], 'application/pdf');
    expect(enriched.values[definition.publishedDateProperty.id], isNull);
  });
}
