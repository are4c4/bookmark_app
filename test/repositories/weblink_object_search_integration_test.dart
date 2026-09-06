import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical Weblink metadata owns its FTS bucket without leaking hidden metadata',
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
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final search = ObjectSearchRepository(genericStore);

    final definition = await weblinks.ensureDefinition(workspaceId);
    final userPropertyId = await objectStore.createProperty(
      objectTypeId: definition.objectType.id,
      name: 'Research note',
      type: ObjectPropertyType.text,
      allowSystemMutation: true,
    );
    final refreshedType =
        (await objectStore.getObjectType(definition.objectType.id))!;
    final userProperty = refreshedType.properties
        .singleWhere((property) => property.id == userPropertyId);

    final weblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/research',
      title: 'Manual object title',
    );
    await objectStore.setPropertyValue(
      objectId: weblink.id,
      property: userProperty,
      value: 'UserDefinedMetadataToken',
    );
    await weblinks.enrichIfMissing(
      workspaceId: workspaceId,
      objectId: weblink.id,
      pageTitle: 'Canonical PageToken',
      siteName: 'Example SiteToken',
      description: 'DescriptionToken is discoverable',
      faviconUrl: 'https://cdn.example.com/favicon-private-token.png',
      previewImageUrl: 'https://cdn.example.com/preview-private-token.jpg',
      contentType: 'application/x-privatecontenttoken',
      publishedDate: '2099-12-31',
    );

    await search.rebuildWorkspace(workspaceId);

    for (final query in <String>[
      'example.com',
      'pagetoken',
      'sitetoken',
      'descriptiontoken',
      'userdefinedmetadatatoken',
    ]) {
      expect(
        (await search.search(workspaceId: workspaceId, rawQuery: query))
            .map((hit) => hit.objectId),
        contains(weblink.id),
        reason: '$query should participate in canonical Object search',
      );
    }

    for (final hiddenQuery in <String>[
      'favicon-private-token',
      'preview-private-token',
      'privatecontenttoken',
      '2099',
    ]) {
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: hiddenQuery,
        ),
        isEmpty,
        reason: '$hiddenQuery is presentation/system metadata, not free text',
      );
    }

    final ftsRow = await database.customSelect(
      '''SELECT properties, weblink_metadata
         FROM object_search_fts
         WHERE CAST(object_id AS INTEGER) = ?''',
      variables: <Variable<Object>>[Variable<int>(weblink.id)],
    ).getSingle();
    final properties = ftsRow.read<String>('properties');
    final weblinkMetadata = ftsRow.read<String>('weblink_metadata');
    expect(properties, 'UserDefinedMetadataToken');
    expect(weblinkMetadata, contains('https://example.com/research'));
    expect(weblinkMetadata, contains('Canonical PageToken'));
    expect(weblinkMetadata, contains('Example SiteToken'));
    expect(weblinkMetadata, contains('DescriptionToken is discoverable'));
    expect(weblinkMetadata, isNot(contains('privatecontenttoken')));
    expect(weblinkMetadata, isNot(contains('favicon-private-token')));
    expect(weblinkMetadata, isNot(contains('preview-private-token')));
    expect(weblinkMetadata, isNot(contains('2099')));

    await objectStore.setPropertyValue(
      objectId: weblink.id,
      property: definition.descriptionProperty,
      value: 'ReplacementMetadataToken',
    );
    await search.refreshObject(weblink.id);

    expect(
      await search.search(
        workspaceId: workspaceId,
        rawQuery: 'descriptiontoken',
      ),
      isEmpty,
      reason: 'focused refresh must remove stale Weblink metadata tokens',
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'replacementmetadatatoken',
      ))
          .map((hit) => hit.objectId),
      contains(weblink.id),
    );
  });
}
