import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent generic creates return the id of their own inserted row',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);

    final databaseIds = await Future.wait(
      List.generate(
        12,
        (index) => store.createDatabase(
          workspaceId: workspaceId,
          name: 'Type $index',
        ),
      ),
    );
    expect(databaseIds.toSet(), hasLength(databaseIds.length));
    final databases = await store.listAllDatabases(workspaceId);
    final databasesById = {
      for (final definition in databases) definition.id: definition,
    };
    for (var index = 0; index < databaseIds.length; index++) {
      expect(databasesById[databaseIds[index]]?.name, 'Type $index');
    }

    final objectTypeId = await store.createDatabase(
      workspaceId: workspaceId,
      name: 'Concurrent children',
    );
    final propertyIds = await Future.wait(
      List.generate(
        24,
        (index) => store.createProperty(
          databaseId: objectTypeId,
          name: 'Property $index',
          type: 'text',
        ),
      ),
    );
    expect(propertyIds.toSet(), hasLength(propertyIds.length));
    final properties = await store.listProperties(objectTypeId);
    final propertiesById = {
      for (final property in properties) property.id: property,
    };
    for (var index = 0; index < propertyIds.length; index++) {
      expect(propertiesById[propertyIds[index]]?.name, 'Property $index');
    }

    final recordIds = await Future.wait(
      List.generate(
        24,
        (index) => store.createRecord(
          databaseId: objectTypeId,
          title: 'Record $index',
        ),
      ),
    );
    expect(recordIds.toSet(), hasLength(recordIds.length));
    final records = await store.listRecords(objectTypeId);
    final recordsById = {for (final record in records) record.id: record};
    for (var index = 0; index < recordIds.length; index++) {
      expect(recordsById[recordIds[index]]?.title, 'Record $index');
    }
  });
}
