import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic value writes accept Properties owned by the Record ObjectType',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);

    final objectTypeId = await store.createDatabase(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final propertyId = await store.createProperty(
      databaseId: objectTypeId,
      name: 'Summary',
      type: 'text',
    );
    final recordId = await store.createRecord(
      databaseId: objectTypeId,
      title: 'Serre',
    );

    await store.setValue(
      recordId: recordId,
      propertyId: propertyId,
      value: 'Local fields',
    );

    final record = (await store.listRecords(objectTypeId)).single;
    expect(record.values[propertyId], 'Local fields');
  });

  test('generic value writes reject foreign Properties before any mutation',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);

    final sourceTypeId = await store.createDatabase(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final foreignTypeId = await store.createDatabase(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final sourcePropertyId = await store.createProperty(
      databaseId: sourceTypeId,
      name: 'Summary',
      type: 'text',
    );
    final foreignPropertyId = await store.createProperty(
      databaseId: foreignTypeId,
      name: 'Biography',
      type: 'text',
    );
    final recordId = await store.createRecord(
      databaseId: sourceTypeId,
      title: 'Serre',
    );
    await store.setValue(
      recordId: recordId,
      propertyId: sourcePropertyId,
      value: 'Owned value',
    );
    const staleTimestamp = '2000-01-01 00:00:00';
    await database.customStatement(
      'UPDATE generic_records SET updated_at = ? WHERE id = ?',
      <Object?>[staleTimestamp, recordId],
    );

    await expectLater(
      store.setValue(
        recordId: recordId,
        propertyId: foreignPropertyId,
        value: 'Foreign value',
      ),
      throwsArgumentError,
    );

    final record = (await store.listRecords(sourceTypeId)).single;
    expect(record.values[sourcePropertyId], 'Owned value');
    expect(record.values.containsKey(foreignPropertyId), isFalse);
    final timestamp = await database.customSelect(
      'SELECT updated_at FROM generic_records WHERE id = ?',
      variables: [Variable<int>(recordId)],
    ).getSingle();
    expect(timestamp.read<String>('updated_at'), staleTimestamp);
  });

  test('generic value writes fail clearly when Record or Property is missing',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);

    final objectTypeId = await store.createDatabase(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final propertyId = await store.createProperty(
      databaseId: objectTypeId,
      name: 'Summary',
      type: 'text',
    );
    final recordId = await store.createRecord(
      databaseId: objectTypeId,
      title: 'Serre',
    );

    await expectLater(
      store.setValue(
        recordId: 999999,
        propertyId: propertyId,
        value: 'Missing Record',
      ),
      throwsArgumentError,
    );
    await expectLater(
      store.setValue(
        recordId: recordId,
        propertyId: 999999,
        value: 'Missing Property',
      ),
      throwsArgumentError,
    );
  });
}
