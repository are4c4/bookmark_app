import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates arbitrary database, properties, records and values', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);

    final databaseId = await store.createDatabase(
      workspaceId: workspaceId,
      name: '書籍',
      icon: '📚',
    );
    final ratingId = await store.createProperty(
      databaseId: databaseId,
      name: '評価',
      type: 'rating',
    );
    final authorId = await store.createProperty(
      databaseId: databaseId,
      name: '著者',
      type: 'text',
    );
    final statusId = await store.createProperty(
      databaseId: databaseId,
      name: '状態',
      type: 'select',
      config: const {
        'options': ['未読', '読書中', '読了'],
      },
    );
    final recordId = await store.createRecord(
      databaseId: databaseId,
      title: '数学書A',
    );

    await store.setValue(recordId: recordId, propertyId: ratingId, value: 5);
    await store.setValue(recordId: recordId, propertyId: authorId, value: '著者A');
    await store.setValue(recordId: recordId, propertyId: statusId, value: '読書中');

    final definitions = await store.listDatabases(workspaceId);
    final properties = await store.listProperties(databaseId);
    final records = await store.listRecords(databaseId);

    expect(definitions.single.name, '書籍');
    expect(definitions.single.icon, '📚');
    expect(properties.map((item) => item.name), ['評価', '著者', '状態']);
    expect(records.single.title, '数学書A');
    expect(records.single.values[ratingId], 5);
    expect(records.single.values[authorId], '著者A');
    expect(records.single.values[statusId], '読書中');
  });

  test('generic databases are isolated by workspace', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceStore = WorkspaceStore(database);
    final first = await workspaceStore.initialize();
    final second = await workspaceStore.createWorkspace('Second');
    final store = GenericDatabaseStore(database);

    await store.createDatabase(workspaceId: first, name: '書籍');
    await store.createDatabase(workspaceId: second, name: '映画');

    expect((await store.listDatabases(first)).map((item) => item.name), ['書籍']);
    expect((await store.listDatabases(second)).map((item) => item.name), ['映画']);
  });

  test('deleting a property removes its values by cascade', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final databaseId = await store.createDatabase(workspaceId: workspaceId, name: '映画');
    final propertyId = await store.createProperty(
      databaseId: databaseId,
      name: '監督',
      type: 'text',
    );
    final recordId = await store.createRecord(databaseId: databaseId, title: '作品A');
    await store.setValue(recordId: recordId, propertyId: propertyId, value: '監督A');

    await store.deleteProperty(propertyId);

    final records = await store.listRecords(databaseId);
    expect(records.single.values, isEmpty);
  });
}
