import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic value update rolls back when parent freshness touch fails',
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
      value: 'before',
    );

    await database.customStatement('''
      CREATE TRIGGER fail_generic_value_parent_touch
      BEFORE UPDATE OF updated_at ON generic_records
      WHEN OLD.id = $recordId
      BEGIN
        SELECT RAISE(ABORT, 'forced parent freshness failure');
      END
    ''');

    await expectLater(
      store.setValue(
        recordId: recordId,
        propertyId: propertyId,
        value: 'after',
      ),
      throwsA(anything),
    );

    final record = (await store.listRecords(objectTypeId)).single;
    expect(record.values[propertyId], 'before');
  });

  test('generic first value insert rolls back when parent freshness touch fails',
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

    await database.customStatement('''
      CREATE TRIGGER fail_generic_value_parent_touch
      BEFORE UPDATE OF updated_at ON generic_records
      WHEN OLD.id = $recordId
      BEGIN
        SELECT RAISE(ABORT, 'forced parent freshness failure');
      END
    ''');

    await expectLater(
      store.setValue(
        recordId: recordId,
        propertyId: propertyId,
        value: 'never committed',
      ),
      throwsA(anything),
    );

    final record = (await store.listRecords(objectTypeId)).single;
    expect(record.values.containsKey(propertyId), isFalse);
  });
}
