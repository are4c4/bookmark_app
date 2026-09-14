import 'dart:convert';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_history_relation_store.dart';
import 'package:bookmark_app/domain/object_history_relation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored source Object key mismatch fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryRelationStore(GenericDatabaseStore(database));
    await store.ensureSchema();

    await database.customStatement(
      '''INSERT INTO object_history_relation_snapshots(
           source_object_id, revision_id, property_id, payload_json
         ) VALUES (?, ?, ?, ?)''',
      <Object>[8, 1, 21, _payload(sourceObjectId: 7, propertyId: 21)],
    );

    await expectLater(
      store.load(sourceObjectId: 8, revisionId: 1, propertyId: 21),
      throwsStateError,
    );
  });

  test('stored Property key mismatch fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final store = ObjectHistoryRelationStore(GenericDatabaseStore(database));
    await store.ensureSchema();

    await database.customStatement(
      '''INSERT INTO object_history_relation_snapshots(
           source_object_id, revision_id, property_id, payload_json
         ) VALUES (?, ?, ?, ?)''',
      <Object>[7, 1, 22, _payload(sourceObjectId: 7, propertyId: 21)],
    );

    await expectLater(
      store.listForRevision(sourceObjectId: 7, revisionId: 1),
      throwsStateError,
    );
  });
}

String _payload({required int sourceObjectId, required int propertyId}) =>
    jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'revisionId': 1,
      'snapshot': ObjectHistoryRelationSnapshot(
        sourceObjectId: sourceObjectId,
        sourceObjectTypeId: 10,
        propertyId: propertyId,
        targetObjectTypeId: 20,
        allowsMultipleRelations: true,
        targetObjectIds: const <int>[12, 11],
      ).toJson(),
    });
