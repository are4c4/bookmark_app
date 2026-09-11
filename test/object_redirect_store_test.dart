import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_redirect_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('redirect survives database reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bookmark-object-redirect-',
    );
    final file = File('${directory.path}/bookmark.sqlite');

    try {
      final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final firstStore = ObjectRedirectStore(
          GenericDatabaseStore(firstDatabase),
        );
        expect(
          await firstStore.recordRedirect(
            retiredObjectId: 30,
            survivorObjectId: 20,
          ),
          isTrue,
        );
      } finally {
        await firstDatabase.close();
      }

      final reopenedDatabase = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final reopenedStore = ObjectRedirectStore(
          GenericDatabaseStore(reopenedDatabase),
        );
        expect(await reopenedStore.resolve(30), 20);
        expect(await reopenedStore.resolve(20), 20);
      } finally {
        await reopenedDatabase.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('historical redirect chain outlives retired Object rows', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final redirectStore = ObjectRedirectStore(genericStore);

    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Mergeable',
    );
    final oldestId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Oldest',
    );
    final middleId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Middle',
    );
    final canonicalId = await objectStore.createObject(
      objectTypeId: objectTypeId,
      title: 'Canonical',
    );

    await redirectStore.recordRedirect(
      retiredObjectId: oldestId,
      survivorObjectId: middleId,
    );
    await redirectStore.recordRedirect(
      retiredObjectId: middleId,
      survivorObjectId: canonicalId,
    );

    await objectStore.deleteObject(oldestId);
    await objectStore.deleteObject(middleId);

    expect(await redirectStore.resolve(oldestId), canonicalId);
    expect(await redirectStore.resolve(middleId), canonicalId);
    expect(await redirectStore.resolve(canonicalId), canonicalId);
  });

  test('same redirect is idempotent and conflicting remap fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final redirectStore = ObjectRedirectStore(GenericDatabaseStore(database));

    expect(
      await redirectStore.recordRedirect(
        retiredObjectId: 30,
        survivorObjectId: 20,
      ),
      isTrue,
    );
    expect(
      await redirectStore.recordRedirect(
        retiredObjectId: 30,
        survivorObjectId: 20,
      ),
      isFalse,
    );

    await expectLater(
      redirectStore.recordRedirect(
        retiredObjectId: 30,
        survivorObjectId: 10,
      ),
      throwsStateError,
    );
    expect(await redirectStore.resolve(30), 20);
  });

  test('cycle introduction is rejected atomically', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final redirectStore = ObjectRedirectStore(GenericDatabaseStore(database));

    await redirectStore.recordRedirect(
      retiredObjectId: 30,
      survivorObjectId: 20,
    );

    await expectLater(
      redirectStore.recordRedirect(
        retiredObjectId: 20,
        survivorObjectId: 30,
      ),
      throwsStateError,
    );

    expect(await redirectStore.resolve(30), 20);
    expect(await redirectStore.resolve(20), 20);
  });

  test('invalid redirect identities fail before mutation', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final redirectStore = ObjectRedirectStore(GenericDatabaseStore(database));

    await expectLater(
      redirectStore.recordRedirect(retiredObjectId: 0, survivorObjectId: 1),
      throwsArgumentError,
    );
    await expectLater(
      redirectStore.recordRedirect(retiredObjectId: 1, survivorObjectId: -1),
      throwsArgumentError,
    );
    await expectLater(
      redirectStore.recordRedirect(retiredObjectId: 1, survivorObjectId: 1),
      throwsArgumentError,
    );
    await expectLater(redirectStore.resolve(0), throwsArgumentError);
  });

  test('unrelated persisted corruption makes resolution fail closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final redirectStore = ObjectRedirectStore(GenericDatabaseStore(database));
    await redirectStore.ensureSchema();

    await database.customStatement(
      'INSERT INTO object_redirects(retired_object_id, survivor_object_id) VALUES (10, 20)',
    );
    await database.customStatement(
      'INSERT INTO object_redirects(retired_object_id, survivor_object_id) VALUES (40, 50)',
    );
    await database.customStatement(
      'INSERT INTO object_redirects(retired_object_id, survivor_object_id) VALUES (50, 40)',
    );

    await expectLater(redirectStore.resolve(10), throwsStateError);
  });

  test('malformed legacy redirect rows fail closed when loaded', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customStatement('''
      CREATE TABLE object_redirects (
        retired_object_id INTEGER PRIMARY KEY,
        survivor_object_id INTEGER NOT NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await database.customStatement(
      'INSERT INTO object_redirects(retired_object_id, survivor_object_id) VALUES (0, 10)',
    );

    final redirectStore = ObjectRedirectStore(GenericDatabaseStore(database));
    await expectLater(redirectStore.resolve(10), throwsStateError);
  });

  test('schema readiness recovers after an enclosing rollback', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final redirectStore = ObjectRedirectStore(GenericDatabaseStore(database));

    await expectLater(
      database.transaction(() async {
        await redirectStore.ensureSchema();
        throw StateError('force rollback');
      }),
      throwsStateError,
    );

    expect(
      await redirectStore.recordRedirect(
        retiredObjectId: 30,
        survivorObjectId: 20,
      ),
      isTrue,
    );
    expect(await redirectStore.resolve(30), 20);
  });
}
