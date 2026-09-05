import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical Relation index bootstraps after v9 database migration', () async {
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        sqlite.execute(
          'CREATE TABLE bookmarks '
          "(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, status TEXT NOT NULL DEFAULT 'unread')",
        );
        sqlite.execute("INSERT INTO bookmarks(id, status) VALUES (1, 'unread')");

        sqlite.execute(
          'CREATE TABLE people '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        sqlite.execute('INSERT INTO people(id) VALUES (1)');

        sqlite.execute('''
          CREATE TABLE bookmark_people (
            bookmark_id INTEGER NOT NULL,
            person_id INTEGER NOT NULL,
            role TEXT NOT NULL DEFAULT '出演',
            PRIMARY KEY (bookmark_id, person_id)
          )
        ''');
        sqlite.execute(
          "INSERT INTO bookmark_people(bookmark_id, person_id, role) "
          "VALUES (1, 1, '出演')",
        );

        sqlite.execute(
          'CREATE TABLE tags '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE)',
        );
        sqlite.execute(
          'CREATE TABLE photos '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );
        sqlite.execute(
          'CREATE TABLE saved_views '
          '(id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT)',
        );

        sqlite.execute('PRAGMA user_version = 9');
      },
    );
    final database = AppDatabase.forTesting(executor);
    addTearDown(database.close);

    await database.customSelect('SELECT 1').get();

    final migratedLegacyRows = await database.customSelect(
      'SELECT bookmark_id, person_id, role FROM bookmark_people',
    ).get();
    expect(migratedLegacyRows, hasLength(1));
    expect(migratedLegacyRows.single.read<String>('role'), '出演者');

    await database.customStatement(
      "INSERT INTO workspaces(name) VALUES ('Relation migration test')",
    );
    final workspaceRow = await database.customSelect(
      'SELECT last_insert_rowid() AS id',
    ).getSingle();
    final workspaceId = workspaceRow.read<int>('id');

    final store = ObjectStore(GenericDatabaseStore(database));

    final targetTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final sourceTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final relationPropertyId = await store.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Related',
      targetObjectTypeId: targetTypeId,
      multiple: false,
    );
    final relationProperty = (await store.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((property) => property.id == relationPropertyId);

    final targetId = await store.createObject(
      objectTypeId: targetTypeId,
      title: 'Target A',
    );
    final sourceId = await store.createObject(
      objectTypeId: sourceTypeId,
      title: 'Source A',
    );

    await store.setRelation(
      objectId: sourceId,
      property: relationProperty,
      targetObjectIds: [targetId],
    );

    final indexTable = await database.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name = 'object_relation_edges'",
    ).get();
    expect(indexTable, hasLength(1));

    final outgoing = await store.outgoingRelations(sourceId);
    final backlinks = await store.backlinks(targetId);
    expect(outgoing, hasLength(1));
    expect(outgoing.single.sourceObjectId, sourceId);
    expect(outgoing.single.targetObjectId, targetId);
    expect(outgoing.single.propertyId, relationPropertyId);
    expect(backlinks, hasLength(1));
    expect(backlinks.single.sourceObjectId, sourceId);

    final legacyRowsAfterRelationWrite = await database.customSelect(
      'SELECT bookmark_id, person_id, role FROM bookmark_people',
    ).get();
    expect(legacyRowsAfterRelationWrite, hasLength(1));
    expect(legacyRowsAfterRelationWrite.single.read<String>('role'), '出演者');
  });
}
