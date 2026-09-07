import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/repositories/object_search_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'corrupt ObjectType schema is isolated from canonical search rebuild',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final search = ObjectSearchRepository(genericStore);

      final healthyTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Healthy',
      );
      final corruptTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Corruptible',
      );
      final corruptPropertyId = await objectStore.createProperty(
        objectTypeId: corruptTypeId,
        name: 'Notes',
        type: ObjectPropertyType.text,
      );
      final healthyObjectId = await objectStore.createObject(
        objectTypeId: healthyTypeId,
        title: 'HealthySearchToken',
      );
      final corruptObjectId = await objectStore.createObject(
        objectTypeId: corruptTypeId,
        title: 'CorruptSearchToken',
      );

      await search.rebuildWorkspace(workspaceId);
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'healthysearch',
        ))
            .map((hit) => hit.objectId),
        contains(healthyObjectId),
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'corruptsearch',
        ))
            .map((hit) => hit.objectId),
        contains(corruptObjectId),
      );

      await database.customStatement(
        'UPDATE generic_properties SET type = ? WHERE id = ?',
        ['futureRichText', corruptPropertyId],
      );

      await search.refreshObject(corruptObjectId);
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'corruptsearch',
        ),
        isEmpty,
        reason: 'focused refresh must remove the stale row for a corrupt type',
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'healthysearch',
        ))
            .map((hit) => hit.objectId),
        contains(healthyObjectId),
        reason: 'focused corruption isolation must not disturb healthy types',
      );

      await objectStore.renameObject(healthyObjectId, 'UpdatedHealthySearchToken');
      await search.rebuildWorkspace(workspaceId);
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'healthysearch',
        ),
        isEmpty,
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'updatedhealthysearch',
        ))
            .map((hit) => hit.objectId),
        contains(healthyObjectId),
        reason: 'workspace rebuild must continue indexing healthy ObjectTypes',
      );
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'corruptsearch',
        ),
        isEmpty,
      );

      await database.customStatement(
        'UPDATE generic_properties SET type = ? WHERE id = ?',
        ['text', corruptPropertyId],
      );
      await search.refreshObject(corruptObjectId);
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'corruptsearch',
        ))
            .map((hit) => hit.objectId),
        contains(corruptObjectId),
        reason: 'repairing the canonical schema must restore normal indexing',
      );
    },
  );
}
