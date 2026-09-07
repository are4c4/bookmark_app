import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visited detail refresh removes stale row for a deleted Object', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final search = ObjectGlobalSearchService(store);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Visited item',
    );
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'DeletedVisitedToken',
    );
    await search.rebuildWorkspace(workspaceId);

    Future<int> ftsRows() async {
      final rows = await database.customSelect(
        '''SELECT rowid
           FROM object_search_fts
           WHERE CAST(object_id AS INTEGER) = ?''',
        variables: <Variable<Object>>[Variable<int>(objectId)],
      ).get();
      return rows.length;
    }

    expect(await ftsRows(), 1);
    await objectStore.deleteObject(objectId);

    await search.refreshVisitedDetailReturnObjects(<int>[objectId, objectId]);

    expect(
      await ftsRows(),
      0,
      reason:
          'missing visited Objects must still clear their stale canonical FTS row',
    );
  });
}
