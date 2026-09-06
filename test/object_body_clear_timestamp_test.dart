import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clearing persisted Body advances the parent Object updated_at', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Body timestamp',
    );
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'body',
            type: 'paragraph',
            text: 'Content',
          ),
        ],
      ),
    );
    const staleTimestamp = '2000-01-01 00:00:00';
    await database.customStatement(
      'UPDATE generic_records SET updated_at = ? WHERE id = ?',
      <Object?>[staleTimestamp, objectId],
    );

    await bodyStore.clear(objectId);

    expect((await bodyStore.read(objectId)).isEmpty, isTrue);
    final row = await database.customSelect(
      'SELECT updated_at FROM generic_records WHERE id = ?',
      variables: <Variable<Object>>[Variable<int>(objectId)],
    ).getSingle();
    expect(row.read<String>('updated_at'), isNot(staleTimestamp));
  });

  test('re-clearing an empty Body does not manufacture an Object update', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Empty Body',
    );
    await bodyStore.ensureSchema();
    const staleTimestamp = '2000-01-01 00:00:00';
    await database.customStatement(
      'UPDATE generic_records SET updated_at = ? WHERE id = ?',
      <Object?>[staleTimestamp, objectId],
    );

    await bodyStore.clear(objectId);

    final row = await database.customSelect(
      'SELECT updated_at FROM generic_records WHERE id = ?',
      variables: <Variable<Object>>[Variable<int>(objectId)],
    ).getSingle();
    expect(row.read<String>('updated_at'), staleTimestamp);
  });
}
