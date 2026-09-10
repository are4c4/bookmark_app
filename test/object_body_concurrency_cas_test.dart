import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<
    ({
      AppDatabase database,
      GenericDatabaseStore genericStore,
      ObjectBodyStore bodyStore,
      int objectId,
    })
  >
  fixture() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final genericStore = GenericDatabaseStore(database);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(genericStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Body concurrency',
    );
    final bodyStore = ObjectBodyStore(genericStore);
    await bodyStore.ensureSchema();
    return (
      database: database,
      genericStore: genericStore,
      bodyStore: bodyStore,
      objectId: objectId,
    );
  }

  test(
    'CAS accepts a semantically equal noncanonical historical snapshot',
    () async {
      final setup = await fixture();
      addTearDown(setup.database.close);
      const expected = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'before'),
        ],
      );
      const next = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'after'),
        ],
      );

      await setup.genericStore.database.customStatement(
        '''INSERT INTO object_bodies(object_id, document_json, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)''',
        [
          setup.objectId,
          '''{
          "blocks": [
            {"type":"paragraph", "text":"before", "id":"p1"}
          ]
        }''',
        ],
      );

      final committed = await setup.bodyStore.writeIfUnchanged(
        objectId: setup.objectId,
        expected: expected,
        document: next,
      );

      expect(committed, isTrue);
      expect(
        (await setup.bodyStore.read(setup.objectId)).toJson(),
        next.toJson(),
      );
    },
  );

  test(
    'CAS rejects a stale semantic snapshot and preserves the newer Body',
    () async {
      final setup = await fixture();
      addTearDown(setup.database.close);
      const initial = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'initial'),
        ],
      );
      const newer = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'newer'),
        ],
      );
      const staleReplacement = ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(id: 'p1', type: 'paragraph', text: 'stale'),
        ],
      );
      await setup.bodyStore.write(objectId: setup.objectId, document: initial);
      final staleSnapshot = await setup.bodyStore.read(setup.objectId);
      await setup.bodyStore.write(objectId: setup.objectId, document: newer);

      final committed = await setup.bodyStore.writeIfUnchanged(
        objectId: setup.objectId,
        expected: staleSnapshot,
        document: staleReplacement,
      );

      expect(committed, isFalse);
      expect(
        (await setup.bodyStore.read(setup.objectId)).toJson(),
        newer.toJson(),
      );
    },
  );
}
