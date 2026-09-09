import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/database_collection_resolver.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GenericDatabaseStore genericStore;
  late ObjectStore objectStore;
  late DatabaseCollectionStore collectionStore;
  late DatabaseCollectionResolver resolver;
  late RelationMutationService relationMutations;
  late TagObjectBridge tagBridge;
  late TagObjectSchema tagSchema;
  late int workspaceId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    genericStore = GenericDatabaseStore(database);
    objectStore = ObjectStore(genericStore);
    collectionStore = DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    resolver = DatabaseCollectionResolver(
      collectionStore: collectionStore,
      objectStore: objectStore,
    );
    relationMutations = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      genericStore: genericStore,
    );
    tagBridge = TagObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
    );
    tagSchema = await tagBridge.ensureTagObjectType(workspaceId);
  });

  tearDown(() => database.close());

  test(
    'collection hierarchy filter consumes canonical Tag Parent snapshot',
    () async {
      final rootId = await objectStore.createObject(
        objectTypeId: tagSchema.objectType.id,
        title: 'くだもの',
      );
      final childId = await objectStore.createObject(
        objectTypeId: tagSchema.objectType.id,
        title: 'りんご',
      );
      final grandchildId = await objectStore.createObject(
        objectTypeId: tagSchema.objectType.id,
        title: '青りんご',
      );
      await tagBridge.hierarchyIntegrity.setParent(
        workspaceId: workspaceId,
        tagObjectId: childId,
        parentProperty: tagSchema.parentProperty,
        parentTagObjectId: rootId,
      );
      await tagBridge.hierarchyIntegrity.setParent(
        workspaceId: workspaceId,
        tagObjectId: grandchildId,
        parentProperty: tagSchema.parentProperty,
        parentTagObjectId: childId,
      );

      final recipeTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Recipe',
      );
      final tagsPropertyId = await objectStore.createRelationProperty(
        objectTypeId: recipeTypeId,
        name: 'Tags',
        targetObjectTypeId: tagSchema.objectType.id,
        multiple: true,
      );
      final recipeType = (await objectStore.getObjectType(recipeTypeId))!;
      final tagsProperty = recipeType.properties.singleWhere(
        (property) => property.id == tagsPropertyId,
      );
      final directRootId = await objectStore.createObject(
        objectTypeId: recipeTypeId,
        title: 'Root direct',
      );
      final directGrandchildId = await objectStore.createObject(
        objectTypeId: recipeTypeId,
        title: 'Grandchild direct',
      );
      await relationMutations.setRelation(
        objectId: directRootId,
        property: tagsProperty,
        targetObjectIds: <int>[rootId],
      );
      await relationMutations.setRelation(
        objectId: directGrandchildId,
        property: tagsProperty,
        targetObjectIds: <int>[grandchildId],
      );

      final databaseId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Fruit recipes',
      );
      await collectionStore.write(
        DatabaseCollectionDefinition(
          databaseId: databaseId,
          workspaceId: workspaceId,
          targetObjectTypeId: recipeTypeId,
          collectionFilter: <ObjectFilterRule>[
            ObjectFilterRule(
              propertyId: tagsPropertyId,
              operator: ObjectFilterOperator.containsAny,
              value: <int>[rootId],
              hierarchyMatchMode: ObjectHierarchyMatchMode.isOrBelow,
            ),
          ],
        ),
      );

      final descendantAware = await resolver.resolve(databaseId);
      expect(
        descendantAware?.objects.map((object) => object.title).toSet(),
        <String>{'Root direct', 'Grandchild direct'},
      );

      await collectionStore.write(
        DatabaseCollectionDefinition(
          databaseId: databaseId,
          workspaceId: workspaceId,
          targetObjectTypeId: recipeTypeId,
          collectionFilter: <ObjectFilterRule>[
            ObjectFilterRule(
              propertyId: tagsPropertyId,
              operator: ObjectFilterOperator.containsAny,
              value: <int>[rootId],
            ),
          ],
        ),
      );
      final exact = await resolver.resolve(databaseId);
      expect(exact?.objects.map((object) => object.title).toList(), <String>[
        'Root direct',
      ]);
    },
  );

  test(
    'corrupt canonical Parent snapshot makes hierarchy collection fail closed',
    () async {
      final rootId = await objectStore.createObject(
        objectTypeId: tagSchema.objectType.id,
        title: 'root',
      );
      final childId = await objectStore.createObject(
        objectTypeId: tagSchema.objectType.id,
        title: 'child',
      );
      await tagBridge.hierarchyIntegrity.setParent(
        workspaceId: workspaceId,
        tagObjectId: childId,
        parentProperty: tagSchema.parentProperty,
        parentTagObjectId: rootId,
      );

      final noteTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Note',
      );
      final tagsPropertyId = await objectStore.createRelationProperty(
        objectTypeId: noteTypeId,
        name: 'Tags',
        targetObjectTypeId: tagSchema.objectType.id,
        multiple: true,
      );
      final noteType = (await objectStore.getObjectType(noteTypeId))!;
      final tagsProperty = noteType.properties.singleWhere(
        (property) => property.id == tagsPropertyId,
      );
      final noteId = await objectStore.createObject(
        objectTypeId: noteTypeId,
        title: 'Child tagged',
      );
      await relationMutations.setRelation(
        objectId: noteId,
        property: tagsProperty,
        targetObjectIds: <int>[childId],
      );

      final databaseId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Filtered notes',
      );
      await collectionStore.write(
        DatabaseCollectionDefinition(
          databaseId: databaseId,
          workspaceId: workspaceId,
          targetObjectTypeId: noteTypeId,
          collectionFilter: <ObjectFilterRule>[
            ObjectFilterRule(
              propertyId: tagsPropertyId,
              operator: ObjectFilterOperator.containsAny,
              value: <int>[rootId],
              hierarchyMatchMode: ObjectHierarchyMatchMode.isOrBelow,
            ),
          ],
        ),
      );

      await database.customStatement(
        'UPDATE object_relation_edges SET position = 7 '
        'WHERE source_object_id = ? AND property_id = ?',
        <Object>[childId, tagSchema.parentProperty.id],
      );

      final collection = await resolver.resolve(databaseId);
      expect(collection?.objects, isEmpty);

      final storedNote = (await objectStore.listObjects(noteTypeId)).single;
      expect(
        ObjectRelationValue.fromJson(storedNote.values[tagsPropertyId])
            .objectIds,
        <int>[childId],
      );
    },
  );
}
