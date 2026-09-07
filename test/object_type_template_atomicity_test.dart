import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('late template failure rolls back primitive and user schema together',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final templates = ObjectTypeTemplateStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );

    // Materialize only the infrastructure table outside the template
    // transaction, then fail the final instance registration after primitive
    // and user schema creation have already run.
    expect(await templates.instanceForObjectType(-1), isNull);
    await database.customStatement('''
      CREATE TRIGGER fail_template_instance_insert
      BEFORE INSERT ON object_type_template_instances
      BEGIN
        SELECT RAISE(ABORT, 'forced template instance failure');
      END
    ''');

    const template = ObjectTypeTemplate(
      key: 'atomic-provisioning-test',
      name: 'Atomic template',
      icon: 'A',
      description: 'late failure must roll the whole application back',
      properties: [
        ObjectTypeTemplateProperty(
          name: 'Cover',
          type: 'relation',
          relationTargetSystemKey: ImageObjectService.systemKey,
          relationMultiple: false,
        ),
        ObjectTypeTemplateProperty(name: 'Note', type: 'text'),
      ],
    );

    await expectLater(
      templates.createFromTemplate(
        workspaceId: workspaceId,
        template: template,
      ),
      throwsA(anything),
    );

    expect(
      await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: ImageObjectService.systemKey,
      ),
      isNull,
    );
    expect(
      (await objectStore.listObjectTypes(workspaceId))
          .where((type) => type.name == template.name),
      isEmpty,
    );

    final instanceCount = await database.customSelect(
      '''SELECT COUNT(*) AS count FROM object_type_template_instances
         WHERE template_key = ?''',
      variables: [],
      readsFrom: const {},
    ).getSingle();
    expect(instanceCount.read<int>('count'), 0);
  });
}
