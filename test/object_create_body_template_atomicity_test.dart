import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Body template failure rolls back the new Object row', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Atomic template type',
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(
        bodyTemplate: ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'notes',
              type: 'paragraph',
              text: 'Initial notes',
            ),
          ],
        ),
      ),
    );
    await bodyStore.ensureSchema();
    await database.customStatement('''
      CREATE TRIGGER fail_object_body_insert
      BEFORE INSERT ON object_bodies
      BEGIN
        SELECT RAISE(FAIL, 'forced body insert failure');
      END
    ''');

    await expectLater(
      objectStore.createObject(
        objectTypeId: typeId,
        title: 'Must roll back',
      ),
      throwsA(anything),
    );

    expect(await objectStore.listObjects(typeId), isEmpty);
    final bodyRows = await database.customSelect(
      'SELECT object_id FROM object_bodies',
    ).get();
    expect(bodyRows, isEmpty);
  });
}
