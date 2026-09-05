import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical Relation facade bootstraps after v1 database migration', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        sqlite.execute('''
          CREATE TABLE bookmarks (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            url TEXT NOT NULL,
            title TEXT NOT NULL,
            thumbnail TEXT NULL,
            description TEXT NULL,
            created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER)),
            favorite INTEGER NOT NULL DEFAULT 0
          )
        ''');
        sqlite.execute(
          "INSERT INTO bookmarks(id, url, title, favorite) VALUES "
          "(1, 'https://example.com/v1', 'Original bookmark', 1)",
        );
        sqlite.execute('PRAGMA user_version = 1');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 16);

    final migratedBookmark = await database.customSelect(
      'SELECT id, url, title, favorite, tags FROM bookmarks WHERE id = 1',
    ).getSingle();
    expect(migratedBookmark.read<int>('id'), 1);
    expect(migratedBookmark.read<String>('url'), 'https://example.com/v1');
    expect(migratedBookmark.read<String>('title'), 'Original bookmark');
    expect(migratedBookmark.read<int>('favorite'), 1);
    expect(migratedBookmark.read<String>('tags'), '');

    final migratedTables = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('people', 'bookmark_people', 'bookmark_relations')",
    ).get();
    expect(
      migratedTables.map((row) => row.read<String>('name')).toSet(),
      {'people', 'bookmark_people', 'bookmark_relations'},
    );

    await database.customStatement(
      "INSERT INTO people(name) VALUES ('Legacy person')",
    );
    final personRow = await database.customSelect(
      'SELECT last_insert_rowid() AS id',
    ).getSingle();
    final personId = personRow.read<int>('id');
    await database.customStatement(
      "INSERT INTO bookmark_people(bookmark_id, person_id, role) "
      "VALUES (1, ?, '出演者')",
      [personId],
    );

    await database.customStatement(
      "INSERT INTO bookmarks(url, title) VALUES "
      "('https://example.com/second', 'Second legacy bookmark')",
    );
    final secondBookmarkRow = await database.customSelect(
      'SELECT last_insert_rowid() AS id',
    ).getSingle();
    final secondBookmarkId = secondBookmarkRow.read<int>('id');
    await database.customStatement(
      "INSERT INTO bookmark_relations(source_bookmark_id, target_bookmark_id, relation_type) "
      "VALUES (1, ?, 'related')",
      [secondBookmarkId],
    );

    await database.customStatement(
      "INSERT INTO workspaces(name) VALUES ('Relation v1 migration test')",
    );
    final workspaceRow = await database.customSelect(
      'SELECT last_insert_rowid() AS id',
    ).getSingle();
    final workspaceId = workspaceRow.read<int>('id');

    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );
    final reads = RelationReadService(objectStore);
    final integrity = RelationIntegrityService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
    );

    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final relationPropertyId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Related',
      targetObjectTypeId: targetTypeId,
      multiple: false,
    );
    final relationProperty = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((property) => property.id == relationPropertyId);

    final targetId = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'Target A',
    );
    final sourceId = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source A',
    );

    await mutations.setRelation(
      objectId: sourceId,
      property: relationProperty,
      targetObjectIds: [targetId],
    );

    final resolvedOutgoing = await reads.outgoing(
      sourceObjectTypeId: sourceTypeId,
      sourceObjectId: sourceId,
    );
    final resolvedBacklinks = await reads.backlinks(
      workspaceId: workspaceId,
      targetObjectId: targetId,
    );
    expect(resolvedOutgoing, hasLength(1));
    expect(resolvedOutgoing.single.targetObject.id, targetId);
    expect(resolvedOutgoing.single.property.id, relationPropertyId);
    expect(resolvedBacklinks, hasLength(1));
    expect(resolvedBacklinks.single.sourceObject.id, sourceId);
    expect(resolvedBacklinks.single.property.id, relationPropertyId);
    expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);

    final indexTable = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'object_relation_edges'",
    ).get();
    expect(indexTable, hasLength(1));

    final legacyPeopleAfterRelationWrite = await database.customSelect(
      'SELECT bookmark_id, person_id, role FROM bookmark_people',
    ).get();
    expect(legacyPeopleAfterRelationWrite, hasLength(1));
    expect(legacyPeopleAfterRelationWrite.single.read<int>('bookmark_id'), 1);
    expect(legacyPeopleAfterRelationWrite.single.read<int>('person_id'), personId);
    expect(legacyPeopleAfterRelationWrite.single.read<String>('role'), '出演者');

    final legacyRelationsAfterRelationWrite = await database.customSelect(
      'SELECT source_bookmark_id, target_bookmark_id, relation_type '
      'FROM bookmark_relations',
    ).get();
    expect(legacyRelationsAfterRelationWrite, hasLength(1));
    expect(legacyRelationsAfterRelationWrite.single.read<int>('source_bookmark_id'), 1);
    expect(
      legacyRelationsAfterRelationWrite.single.read<int>('target_bookmark_id'),
      secondBookmarkId,
    );
    expect(
      legacyRelationsAfterRelationWrite.single.read<String>('relation_type'),
      'related',
    );
  });
}
