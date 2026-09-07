import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('malformed checklist Body template does not replace existing defaults',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Task',
    );
    final statusPropertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'Status',
      type: ObjectPropertyType.text,
    );

    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds: <int>[statusPropertyId],
        openMode: ObjectOpenMode.fullPage,
        bodyTemplate: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'safe-checklist',
              type: ObjectBodyBlockType.checklist,
              text: 'Review',
              attributes: <String, dynamic>{
                ObjectBodyBlockAttribute.checked: false,
              },
            ),
          ],
        ),
      ),
    );

    await expectLater(
      defaultsStore.writeBodyTemplate(
        objectTypeId: typeId,
        bodyTemplate: const ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'broken-checklist',
              type: ObjectBodyBlockType.checklist,
              text: 'Broken',
              attributes: <String, dynamic>{
                ObjectBodyBlockAttribute.checked: 'false',
              },
            ),
          ],
        ),
      ),
      throwsFormatException,
    );

    final restored = await defaultsStore.read(typeId);
    expect(restored, isNotNull);
    expect(restored!.visiblePropertyIds, <int>[statusPropertyId]);
    expect(restored.openMode, ObjectOpenMode.fullPage);
    expect(restored.bodyTemplate?.blocks.single.id, 'safe-checklist');
    expect(
      restored.bodyTemplate?.blocks.single
          .attributes[ObjectBodyBlockAttribute.checked],
      isFalse,
    );
  });

  test('unknown Body template block keeps opaque checked-like attribute',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Future template',
    );

    await defaultsStore.writeBodyTemplate(
      objectTypeId: typeId,
      bodyTemplate: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'future',
            type: 'futureChecklist',
            attributes: <String, dynamic>{
              ObjectBodyBlockAttribute.checked: 'opaque',
            },
          ),
        ],
      ),
    );

    final restored = await defaultsStore.read(typeId);
    expect(restored?.bodyTemplate?.blocks.single.type, 'futureChecklist');
    expect(
      restored?.bodyTemplate?.blocks.single
          .attributes[ObjectBodyBlockAttribute.checked],
      'opaque',
    );
  });
}
