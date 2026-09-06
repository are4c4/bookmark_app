import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalid Body template update fails closed and preserves current defaults',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Validated template type',
    );
    await defaultsStore.write(
      objectTypeId: typeId,
      defaults: const ObjectTypeDefaults(
        openMode: ObjectOpenMode.centerPeek,
        bodyTemplate: ObjectBodyDocument(
          blocks: <ObjectBodyBlock>[
            ObjectBodyBlock(
              id: 'notes',
              type: 'paragraph',
              text: 'Current template',
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
              id: 'duplicate',
              type: 'paragraph',
              text: 'First',
            ),
            ObjectBodyBlock(
              id: 'duplicate',
              type: 'paragraph',
              text: 'Second',
            ),
          ],
        ),
      ),
      throwsFormatException,
    );

    final restored = await defaultsStore.read(typeId);
    expect(restored, isNotNull);
    expect(restored!.openMode, ObjectOpenMode.centerPeek);
    expect(restored.bodyTemplate?.blocks, hasLength(1));
    expect(restored.bodyTemplate?.blocks.single.id, 'notes');
    expect(restored.bodyTemplate?.blocks.single.text, 'Current template');
  });
}
