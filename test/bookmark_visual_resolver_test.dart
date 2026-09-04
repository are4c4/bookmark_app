import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_visual_resolver.dart';
import 'package:bookmark_app/services/object_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visual precedence is user cover, managed image, then legacy remote', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final resolver = BookmarkVisualResolver(database: database, workspaceId: 1);

    final userCover = resolver.choosePreferred(
      userCoverPath: '/user/cover.jpg',
      managedRepresentativePath: '/managed/preview.jpg',
      legacyThumbnailUrl: 'https://example.com/preview.jpg',
    );
    expect(userCover?.kind, BookmarkVisualSourceKind.userCover);
    expect(userCover?.value, '/user/cover.jpg');

    final managed = resolver.choosePreferred(
      managedRepresentativePath: '/managed/preview.jpg',
      legacyThumbnailUrl: 'https://example.com/preview.jpg',
    );
    expect(managed?.kind, BookmarkVisualSourceKind.managedRepresentative);
    expect(managed?.isLocalFile, isTrue);

    final remote = resolver.choosePreferred(
      legacyThumbnailUrl: 'https://example.com/preview.jpg',
    );
    expect(remote?.kind, BookmarkVisualSourceKind.legacyRemote);
    expect(remote?.isLocalFile, isFalse);

    expect(
      resolver.choosePreferred(legacyThumbnailUrl: 'not a remote URL'),
      isNull,
    );
  });

  test('resolver follows canonical Bookmark Weblink Representative Image edges',
      () async {
    final directory = await Directory.systemTemp.createTemp('visual_resolver_');
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/preview.jpg');
    await managedFile.writeAsBytes(<int>[1, 2, 3]);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();

    await database.customStatement(
      '''INSERT INTO bookmarks(url, title, thumbnail)
         VALUES (?, ?, ?)''',
      <Object>[
        'https://example.com/article',
        'Article',
        'https://cdn.example.com/legacy.jpg',
      ],
    );
    final legacyBookmarkId = (await database.customSelect(
      'SELECT id FROM bookmarks LIMIT 1',
    ).getSingle())
        .read<int>('id');
    await database.customStatement(
      'INSERT INTO bookmark_workspace(bookmark_id, workspace_id) VALUES (?, ?)',
      <Object>[legacyBookmarkId, workspaceId],
    );

    final sync = ObjectSyncService(database);
    addTearDown(sync.dispose);
    await sync.syncWorkspace(workspaceId);

    final genericStore = GenericDatabaseStore(database);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final schema = await WeblinkImageSchemaService(
      systemObjects: sync.systemObjectStore,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);
    final image = await ImageObjectService(
      systemObjects: sync.systemObjectStore,
      defaultsStore: defaultsStore,
    ).findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedFile.path,
      sourceUrl: 'https://cdn.example.com/preview.jpg',
    );
    final weblink = (await sync.objectStore.listObjects(
      schema.weblinkObjectTypeId,
    ))
        .single;
    final mutations = RelationMutationService(
      objectStore: sync.objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: sync.objectStore,
      ),
    );
    await mutations.setRelation(
      objectId: weblink.id,
      property: schema.representativeImageProperty,
      targetObjectIds: <int>[image.id],
    );

    final resolver = BookmarkVisualResolver(
      database: database,
      workspaceId: workspaceId,
    );
    expect(
      await resolver.resolveManagedRepresentativePath(legacyBookmarkId),
      managedFile.path,
    );

    await database.customStatement(
      'DELETE FROM object_relation_edges WHERE source_object_id = ? AND property_id = ?',
      <Object>[weblink.id, schema.representativeImageProperty.id],
    );
    expect(
      await resolver.resolveManagedRepresentativePath(legacyBookmarkId),
      isNull,
    );
  });
}
