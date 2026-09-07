import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late ObjectBodyStore bodyStore;
  late ObjectSearchRepository search;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    bodyStore = ObjectBodyStore(genericStore);
    search = ObjectSearchRepository(genericStore);
  });

  test('workspace rebuild isolates malformed Body to its search bucket', () async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Thing',
    );
    final malformedObject = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Malformed body object',
    );
    final healthyObject = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Healthy body object',
    );
    await bodyStore.write(
      objectId: healthyObject,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'healthy-1',
            type: 'paragraph',
            text: 'HealthyBodyToken',
          ),
        ],
      ),
    );
    await bodyStore.ensureSchema();
    await database.customStatement(
      '''INSERT INTO object_bodies(object_id, document_json)
         VALUES (?, ?)''',
      [
        malformedObject,
        '{"version":1,"blocks":{"text":"ShouldNotLeak"}}',
      ],
    );

    await search.rebuildWorkspace(workspaceId);

    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'malformed',
      ))
          .map((hit) => hit.objectId),
      contains(malformedObject),
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'healthybodytoken',
      ))
          .map((hit) => hit.objectId),
      contains(healthyObject),
    );
    expect(
      await search.search(
        workspaceId: workspaceId,
        rawQuery: 'shouldnotleak',
      ),
      isEmpty,
    );
  });

  test('focused refresh removes stale Body tokens after Body becomes malformed',
      () async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Thing',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Stable searchable title',
    );
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'legacy-1',
            type: 'paragraph',
            text: 'LegacyBodyToken',
          ),
        ],
      ),
    );
    await search.rebuildWorkspace(workspaceId);
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'legacybodytoken',
      ))
          .map((hit) => hit.objectId),
      contains(objectId),
    );

    await database.customStatement(
      'UPDATE object_bodies SET document_json = ? WHERE object_id = ?',
      ['{"version":"broken","blocks":[]}', objectId],
    );

    await search.refreshObject(objectId);

    expect(
      await search.search(
        workspaceId: workspaceId,
        rawQuery: 'legacybodytoken',
      ),
      isEmpty,
    );
    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'stable',
      ))
          .map((hit) => hit.objectId),
      contains(objectId),
    );
  });

  test('future Body versions and unknown block kinds remain searchable', () async {
    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Thing',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Future body object',
    );
    await bodyStore.write(
      objectId: objectId,
      document: const ObjectBodyDocument(
        version: 99,
        blocks: <ObjectBodyBlock>[
          ObjectBodyBlock(
            id: 'future-1',
            type: 'futureRichBlock',
            text: 'FutureBodyToken',
          ),
        ],
      ),
    );

    await search.rebuildWorkspace(workspaceId);

    expect(
      (await search.search(
        workspaceId: workspaceId,
        rawQuery: 'futurebodytoken',
      ))
          .map((hit) => hit.objectId),
      contains(objectId),
    );
  });
}
