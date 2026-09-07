import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Body document accepts an empty JSON object', () {
    final document = ObjectBodyDocument.fromJson(<String, dynamic>{});

    expect(document.isEmpty, isTrue);
    expect(document.version, ObjectBodyDocument.currentVersion);
  });

  test('Body document preserves an explicit integer future version', () {
    final document = ObjectBodyDocument.fromJson(<String, dynamic>{
      'version': ObjectBodyDocument.currentVersion + 1,
      'blocks': <dynamic>[],
    });

    expect(document.isEmpty, isTrue);
    expect(document.version, ObjectBodyDocument.currentVersion + 1);
  });

  test('Body document rejects malformed top-level JSON shapes', () {
    for (final value in <dynamic>[
      null,
      <dynamic>[],
      'not-an-object',
      42,
      true,
    ]) {
      expect(
        () => ObjectBodyDocument.fromJson(value),
        throwsFormatException,
        reason: 'Unexpectedly accepted $value',
      );
    }
  });

  test('Body document rejects malformed version and blocks field shapes', () {
    for (final value in <Map<String, dynamic>>[
      <String, dynamic>{'version': null},
      <String, dynamic>{'version': '1'},
      <String, dynamic>{'blocks': null},
      <String, dynamic>{'blocks': <String, dynamic>{}},
      <String, dynamic>{'blocks': 'not-an-array'},
    ]) {
      expect(
        () => ObjectBodyDocument.fromJson(value),
        throwsFormatException,
        reason: 'Unexpectedly accepted $value',
      );
    }
  });

  test('persisted non-object Body JSON fails closed instead of reading empty',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Corrupt Body',
    );
    await bodyStore.ensureSchema();
    await database.customStatement(
      '''INSERT INTO object_bodies(object_id, document_json, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)''',
      <Object?>[objectId, '[]'],
    );

    await expectLater(bodyStore.read(objectId), throwsFormatException);
  });

  test('persisted malformed Body fields fail closed instead of reading empty',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final bodyStore = ObjectBodyStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Note',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Corrupt Body fields',
    );
    await bodyStore.ensureSchema();
    await database.customStatement(
      '''INSERT INTO object_bodies(object_id, document_json, updated_at)
         VALUES (?, ?, CURRENT_TIMESTAMP)''',
      <Object?>[objectId, '{"version":"1","blocks":{}}'],
    );

    await expectLater(bodyStore.read(objectId), throwsFormatException);
  });
}
