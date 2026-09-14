import 'dart:convert';
import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_history_relation_store.dart';
import 'package:bookmark_app/domain/object_history_relation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Relation snapshots survive reopen with exact target order', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bookmark-relation-history-',
    );
    final file = File('${directory.path}/bookmark.sqlite');

    try {
      final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final store = ObjectHistoryRelationStore(
          GenericDatabaseStore(firstDatabase),
        );
        expect(
          await store.append(revisionId: 3, snapshot: _snapshot()),
          isTrue,
        );
        expect(
          await store.append(
            revisionId: 3,
            snapshot: _snapshot(
              propertyId: 22,
              targetObjectIds: <int>[15],
              allowsMultipleRelations: false,
            ),
          ),
          isTrue,
        );
      } finally {
        await firstDatabase.close();
      }

      final reopenedDatabase = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final store = ObjectHistoryRelationStore(
          GenericDatabaseStore(reopenedDatabase),
        );
        final snapshots = await store.listForRevision(
          sourceObjectId: 7,
          revisionId: 3,
        );
        expect(snapshots.map((item) => item.propertyId), <int>[21, 22]);
        expect(snapshots.first.targetObjectIds, <int>[12, 11]);
        expect(
          (await store.load(
            sourceObjectId: 7,
            revisionId: 3,
            propertyId: 21,
          ))?.targetObjectIds,
          <int>[12, 11],
        );
      } finally {
        await reopenedDatabase.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'exact retry is idempotent and conflicting key reuse fails closed',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final store = ObjectHistoryRelationStore(GenericDatabaseStore(database));

      expect(await store.append(revisionId: 4, snapshot: _snapshot()), isTrue);
      expect(await store.append(revisionId: 4, snapshot: _snapshot()), isFalse);

      await expectLater(
        store.append(
          revisionId: 4,
          snapshot: _snapshot(targetObjectIds: <int>[11, 12]),
        ),
        throwsStateError,
      );
      expect(
        (await store.load(
          sourceObjectId: 7,
          revisionId: 4,
          propertyId: 21,
        ))?.targetObjectIds,
        <int>[12, 11],
      );
    },
  );

  test(
    'bidirectional metadata persists without becoming Relation authority',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final store = ObjectHistoryRelationStore(GenericDatabaseStore(database));
      final snapshot = _snapshot(
        inversePropertyId: 31,
        pairRole: ObjectHistoryRelationPairRole.source,
        inverseAllowsMultipleRelations: false,
      );

      await store.append(revisionId: 5, snapshot: snapshot);
      final restored = await store.load(
        sourceObjectId: 7,
        revisionId: 5,
        propertyId: 21,
      );

      expect(restored?.inversePropertyId, 31);
      expect(restored?.pairRole, ObjectHistoryRelationPairRole.source);
      expect(restored?.inverseAllowsMultipleRelations, isFalse);
    },
  );

  test('malformed persisted JSON and key disagreement fail closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryRelationStore(GenericDatabaseStore(database));
    await store.ensureSchema();

    await database.customStatement(
      '''INSERT INTO object_history_relation_snapshots(
           source_object_id, revision_id, property_id, payload_json
         ) VALUES (?, ?, ?, ?)''',
      <Object>[7, 1, 21, '{"schemaVersion":999}'],
    );
    await expectLater(
      store.load(sourceObjectId: 7, revisionId: 1, propertyId: 21),
      throwsFormatException,
    );

    await database.customStatement(
      'DELETE FROM object_history_relation_snapshots',
    );
    final payload = jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'revisionId': 2,
      'snapshot': _snapshot().toJson(),
    });
    await database.customStatement(
      '''INSERT INTO object_history_relation_snapshots(
           source_object_id, revision_id, property_id, payload_json
         ) VALUES (?, ?, ?, ?)''',
      <Object>[7, 3, 21, payload],
    );

    await expectLater(
      store.listForRevision(sourceObjectId: 7, revisionId: 3),
      throwsStateError,
    );
  });

  test('outer rollback removes writes and schema readiness recovers', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryRelationStore(GenericDatabaseStore(database));

    await expectLater(
      database.transaction(() async {
        await store.append(revisionId: 1, snapshot: _snapshot());
        throw StateError('force rollback');
      }),
      throwsStateError,
    );

    expect(
      await store.load(sourceObjectId: 7, revisionId: 1, propertyId: 21),
      isNull,
    );
    expect(await store.append(revisionId: 1, snapshot: _snapshot()), isTrue);
  });

  test('invalid historical keys fail before persistence reads', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryRelationStore(GenericDatabaseStore(database));

    await expectLater(
      store.append(revisionId: 0, snapshot: _snapshot()),
      throwsArgumentError,
    );
    await expectLater(
      store.listForRevision(sourceObjectId: 0, revisionId: 1),
      throwsArgumentError,
    );
    await expectLater(
      store.load(sourceObjectId: 7, revisionId: -1, propertyId: 21),
      throwsArgumentError,
    );
  });
}

ObjectHistoryRelationSnapshot _snapshot({
  int sourceObjectId = 7,
  int sourceObjectTypeId = 10,
  int propertyId = 21,
  int targetObjectTypeId = 20,
  bool allowsMultipleRelations = true,
  List<int> targetObjectIds = const <int>[12, 11],
  int? inversePropertyId,
  ObjectHistoryRelationPairRole? pairRole,
  bool? inverseAllowsMultipleRelations,
}) => ObjectHistoryRelationSnapshot(
  sourceObjectId: sourceObjectId,
  sourceObjectTypeId: sourceObjectTypeId,
  propertyId: propertyId,
  targetObjectTypeId: targetObjectTypeId,
  allowsMultipleRelations: allowsMultipleRelations,
  targetObjectIds: targetObjectIds,
  inversePropertyId: inversePropertyId,
  pairRole: pairRole,
  inverseAllowsMultipleRelations: inverseAllowsMultipleRelations,
);
