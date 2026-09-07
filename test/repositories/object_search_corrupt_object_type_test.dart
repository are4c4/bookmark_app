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

  test(
    'corrupt Relation target schema omits only relation labels from healthy source',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final search = ObjectSearchRepository(genericStore);

      final sourceTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Book',
      );
      final targetTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Person',
      );
      final targetPropertyId = await objectStore.createProperty(
        objectTypeId: targetTypeId,
        name: 'Bio',
        type: ObjectPropertyType.text,
      );
      final relationPropertyId = await objectStore.createRelationProperty(
        objectTypeId: sourceTypeId,
        name: 'Author',
        targetObjectTypeId: targetTypeId,
        multiple: false,
      );
      final relationProperty = (await objectStore.getObjectType(sourceTypeId))!
          .properties
          .singleWhere((property) => property.id == relationPropertyId);
      final sourceObjectId = await objectStore.createObject(
        objectTypeId: sourceTypeId,
        title: 'HealthySourceSearchToken',
      );
      final targetObjectId = await objectStore.createObject(
        objectTypeId: targetTypeId,
        title: 'TargetRelationSearchToken',
      );
      await objectStore.setRelation(
        objectId: sourceObjectId,
        property: relationProperty,
        targetObjectIds: [targetObjectId],
      );

      await search.rebuildWorkspace(workspaceId);
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'targetrelationsearch',
        ))
            .map((hit) => hit.objectId),
        containsAll(<int>[sourceObjectId, targetObjectId]),
      );

      await database.customStatement(
        'UPDATE generic_properties SET type = ? WHERE id = ?',
        ['futureRichText', targetPropertyId],
      );

      await search.rebuildWorkspace(workspaceId);
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'healthysourcesearch',
        ))
            .map((hit) => hit.objectId),
        contains(sourceObjectId),
        reason: 'healthy source identity must survive corrupt Relation target',
      );
      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'targetrelationsearch',
        ),
        isEmpty,
        reason: 'corrupt target title and dependent relation label must be omitted',
      );

      await database.customStatement(
        'UPDATE generic_properties SET type = ? WHERE id = ?',
        ['text', targetPropertyId],
      );
      await search.rebuildWorkspace(workspaceId);
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'targetrelationsearch',
        ))
            .map((hit) => hit.objectId),
        containsAll(<int>[sourceObjectId, targetObjectId]),
        reason: 'schema repair must restore target identity and relation label',
      );
    },
  );
}
