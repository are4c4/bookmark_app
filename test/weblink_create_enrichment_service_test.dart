import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_metadata_service.dart';
import 'package:bookmark_app/services/weblink_create_enrichment_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create enrichment persists useful metadata before preview ingestion',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final weblinks = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await weblinks.ensureDefinition(workspaceId);
    final weblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/article',
    );
    var previewCalled = false;
    final enrichment = WeblinkCreateEnrichmentService(
      weblinks: weblinks,
      metadataFetch: (_) async => const BookmarkMetadata(
        url: 'https://example.com/article',
        title: 'Readable article title',
        siteName: 'Resource Site',
        description: 'Resource description',
        faviconUrl: 'https://example.com/favicon.ico',
        thumbnail: 'https://cdn.example.com/preview.jpg',
      ),
      previewImageIngest: ({
        required workspaceId,
        required weblinkObjectId,
      }) async {
        previewCalled = true;
        final current = (await objectStore.listObjects(
          definition.objectType.id,
        ))
            .singleWhere((object) => object.id == weblinkObjectId);
        expect(current.title, 'Readable article title');
        expect(current.values[definition.siteNameProperty.id], 'Resource Site');
        expect(
          current.values[definition.faviconUrlProperty.id],
          'https://example.com/favicon.ico',
        );
        expect(
          current.values[definition.previewImageUrlProperty.id],
          'https://cdn.example.com/preview.jpg',
        );
        return null;
      },
    );

    await enrichment.enrich(
      workspaceId: workspaceId,
      objectId: weblink.id,
      url: 'https://example.com/article',
    );

    final enriched = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == weblink.id);
    expect(enriched.title, 'Readable article title');
    expect(
      enriched.values[definition.pageTitleProperty.id],
      'Readable article title',
    );
    expect(enriched.values[definition.siteNameProperty.id], 'Resource Site');
    expect(
      enriched.values[definition.descriptionProperty.id],
      'Resource description',
    );
    expect(
      enriched.values[definition.faviconUrlProperty.id],
      'https://example.com/favicon.ico',
    );
    expect(previewCalled, isTrue);
  });

  test('host fallback title is not claimed when site or preview metadata is useful',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final weblinks = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await weblinks.ensureDefinition(workspaceId);
    final weblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.org/fallback',
    );
    var previewCalled = false;
    final enrichment = WeblinkCreateEnrichmentService(
      weblinks: weblinks,
      metadataFetch: (_) async => const BookmarkMetadata(
        url: 'https://example.org/fallback',
        title: 'example.org',
        siteName: 'Fallback Site',
        thumbnail: 'https://cdn.example.org/preview.jpg',
      ),
      previewImageIngest: ({
        required workspaceId,
        required weblinkObjectId,
      }) async {
        previewCalled = true;
        return null;
      },
    );

    await enrichment.enrich(
      workspaceId: workspaceId,
      objectId: weblink.id,
      url: 'https://example.org/fallback',
    );

    final preserved = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == weblink.id);
    expect(preserved.title, 'example.org');
    expect(preserved.values[definition.pageTitleProperty.id], isNull);
    expect(preserved.values[definition.siteNameProperty.id], 'Fallback Site');
    expect(
      preserved.values[definition.previewImageUrlProperty.id],
      'https://cdn.example.org/preview.jpg',
    );
    expect(previewCalled, isTrue);
  });

  test('metadata and preview failures never remove the canonical Weblink',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final weblinks = WeblinkObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await weblinks.ensureDefinition(workspaceId);
    final weblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.net/failure',
    );
    final enrichment = WeblinkCreateEnrichmentService(
      weblinks: weblinks,
      metadataFetch: (_) async => throw StateError('metadata unavailable'),
      previewImageIngest: ({
        required workspaceId,
        required weblinkObjectId,
      }) async => throw StateError('preview unavailable'),
    );

    await expectLater(
      enrichment.enrich(
        workspaceId: workspaceId,
        objectId: weblink.id,
        url: 'https://example.net/failure',
      ),
      completes,
    );

    final objects = await objectStore.listObjects(definition.objectType.id);
    expect(objects.map((object) => object.id), contains(weblink.id));
  });
}
