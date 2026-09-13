import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_history_checkpoint_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_history_checkpoint.dart';
import 'package:bookmark_app/domain/object_history_checkpoint_codec.dart';
import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkpoints survive reopen and preserve revision order', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bookmark-object-history-',
    );
    final file = File('${directory.path}/bookmark.sqlite');

    try {
      final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final store = ObjectHistoryCheckpointStore(
          GenericDatabaseStore(firstDatabase),
        );
        expect(await store.append(_checkpoint(revisionId: 1)), isTrue);
        expect(
          await store.append(_checkpoint(revisionId: 4, previousRevisionId: 1)),
          isTrue,
        );
      } finally {
        await firstDatabase.close();
      }

      final reopenedDatabase = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final store = ObjectHistoryCheckpointStore(
          GenericDatabaseStore(reopenedDatabase),
        );
        final checkpoints = await store.list(7);
        expect(
          checkpoints.map((item) => item.entry.revisionId),
          <int>[1, 4],
        );
        expect((await store.latest(7))?.entry.revisionId, 4);
        expect((await store.load(objectId: 7, revisionId: 1))?.title, 'Title 1');
        expect(await store.load(objectId: 7, revisionId: 2), isNull);
        expect(
          await store.append(_checkpoint(revisionId: 4, previousRevisionId: 1)),
          isFalse,
        );
      } finally {
        await reopenedDatabase.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('append enforces an immutable linear revision chain', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryCheckpointStore(GenericDatabaseStore(database));

    expect(await store.append(_checkpoint(revisionId: 2)), isTrue);
    await expectLater(
      store.append(
        _checkpoint(
          revisionId: 2,
          title: 'Conflicting reuse',
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      store.append(_checkpoint(revisionId: 3, previousRevisionId: 1)),
      throwsStateError,
    );
    await expectLater(
      store.append(_checkpoint(revisionId: 1)),
      throwsStateError,
    );

    expect(
      (await store.list(7)).map((item) => item.entry.revisionId),
      <int>[2],
    );
  });

  test('first checkpoint cannot claim a previous revision', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryCheckpointStore(GenericDatabaseStore(database));

    await expectLater(
      store.append(_checkpoint(revisionId: 3, previousRevisionId: 2)),
      throwsStateError,
    );
    expect(await store.list(7), isEmpty);
  });

  test('persisted payload remains A-owned and excludes Relation targets', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryCheckpointStore(GenericDatabaseStore(database));

    await store.append(_checkpoint(revisionId: 1));
    final row = await database.customSelect(
      'SELECT payload_json FROM object_history_checkpoints LIMIT 1',
    ).getSingle();
    final stored = row.read<String>('payload_json');

    expect(stored, contains('relationPropertyIds'));
    expect(stored, isNot(contains('targetObjectIds')));
    expect(stored, isNot(contains('object_relation_edges')));
  });

  test('malformed persisted checkpoint fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryCheckpointStore(GenericDatabaseStore(database));
    await store.ensureSchema();

    await database.customStatement(
      '''INSERT INTO object_history_checkpoints(
           object_id, revision_id, payload_json
         ) VALUES (?, ?, ?)''',
      [7, 1, '{"schemaVersion":999}'],
    );

    await expectLater(store.list(7), throwsFormatException);
  });

  test('stored key and payload identity disagreement fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryCheckpointStore(GenericDatabaseStore(database));
    await store.ensureSchema();
    const codec = ObjectHistoryCheckpointCodec();
    final payload = jsonEncode(codec.encode(_checkpoint(revisionId: 1)));

    await database.customStatement(
      '''INSERT INTO object_history_checkpoints(
           object_id, revision_id, payload_json
         ) VALUES (?, ?, ?)''',
      [7, 9, payload],
    );

    await expectLater(store.list(7), throwsStateError);
  });

  test('broken persisted revision chain fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryCheckpointStore(GenericDatabaseStore(database));
    await store.ensureSchema();
    const codec = ObjectHistoryCheckpointCodec();

    final first = jsonEncode(codec.encode(_checkpoint(revisionId: 1)));
    final broken = jsonEncode(
      codec.encode(_checkpoint(revisionId: 4, previousRevisionId: 3)),
    );
    await database.customStatement(
      '''INSERT INTO object_history_checkpoints(
           object_id, revision_id, payload_json
         ) VALUES (?, ?, ?)''',
      [7, 1, first],
    );
    await database.customStatement(
      '''INSERT INTO object_history_checkpoints(
           object_id, revision_id, payload_json
         ) VALUES (?, ?, ?)''',
      [7, 4, broken],
    );

    await expectLater(store.latest(7), throwsStateError);
  });

  test('schema readiness recovers after an enclosing rollback', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryCheckpointStore(GenericDatabaseStore(database));

    await expectLater(
      database.transaction(() async {
        await store.ensureSchema();
        throw StateError('force rollback');
      }),
      throwsStateError,
    );

    expect(await store.append(_checkpoint(revisionId: 1)), isTrue);
    expect((await store.latest(7))?.entry.revisionId, 1);
  });

  test('invalid lookup identities fail before persistence reads', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryCheckpointStore(GenericDatabaseStore(database));

    await expectLater(store.list(0), throwsArgumentError);
    await expectLater(store.latest(-1), throwsArgumentError);
    await expectLater(
      store.load(objectId: 7, revisionId: 0),
      throwsArgumentError,
    );
  });
}

ObjectHistoryCheckpointPayload _checkpoint({
  int objectId = 7,
  required int revisionId,
  int? previousRevisionId,
  String? title,
}) => ObjectHistoryCheckpointPayload(
  entry: ObjectHistoryEntry(
    objectId: objectId,
    revisionId: revisionId,
    previousRevisionId: previousRevisionId,
    capturedAt: DateTime.utc(2026, 9, 13, 10, revisionId),
    source: ObjectHistorySourceKind.userMutation,
  ),
  title: title ?? 'Title $revisionId',
  propertySnapshots: <ObjectHistoryPropertySnapshot>[
    ObjectHistoryPropertySnapshot.fromDefinition(
      property: _property(11, ObjectPropertyType.text),
      value: <String, dynamic>{'value': 'v$revisionId'},
    ),
  ],
  body: ObjectBodyDocument(
    blocks: <ObjectBodyBlock>[
      ObjectBodyBlock(
        id: 'p',
        type: ObjectBodyBlockType.paragraph,
        text: 'Body $revisionId',
      ),
    ],
  ),
  relationRequirements: <ObjectHistoryRelationRequirement>[
    ObjectHistoryRelationRequirement.fromDefinition(
      _property(21, ObjectPropertyType.objectRelation),
    ),
  ],
);

ObjectPropertyDefinition _property(int id, ObjectPropertyType type) =>
    ObjectPropertyDefinition(
      id: id,
      objectTypeId: 1,
      name: 'Property $id',
      type: type,
      sortOrder: id,
    );
