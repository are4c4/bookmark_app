import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/database/database_definition.dart';
import 'package:bookmark_app/domain/object_query.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'real generic host applies canonical Tag descendant View filter',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceStore = WorkspaceStore(database);
      final workspaceId = await workspaceStore.initialize();
      final lifecycleStore = BookmarkLifecycleStore(database);
      await lifecycleStore.initialize();
      final repository = BookmarkRepository(
        database,
        workspaceStore: workspaceStore,
        lifecycleStore: lifecycleStore,
        workspaceId: workspaceId,
      );
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final tagBridge = TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjects,
      );
      final tagSchema = await tagBridge.ensureTagObjectType(workspaceId);
      final relationMutations = RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
        genericStore: genericStore,
      );

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
        name: 'レシピ',
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
        title: '親を直接付与',
      );
      final directGrandchildId = await objectStore.createObject(
        objectTypeId: recipeTypeId,
        title: '孫を直接付与',
      );
      await objectStore.createObject(objectTypeId: recipeTypeId, title: '対象外');
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

      final viewStore = DatabaseViewStore(database);
      await viewStore.createView(
        workspaceId: workspaceId,
        definition: DatabaseDefinition(
          key: 'custom:$recipeTypeId',
          label: 'レシピ',
          icon: Icons.table_chart_outlined,
          properties: const <DatabasePropertyDefinition>[],
          defaultLayout: 'table',
          supportedLayouts: const <String>['gallery', 'list', 'table', 'board'],
        ),
        name: 'くだもの配下',
        layoutType: 'table',
        filters: <String, dynamic>{
          'query': '',
          'propertyRules': <Map<String, dynamic>>[
            ObjectFilterRule(
              propertyId: tagsPropertyId,
              operator: ObjectFilterOperator.containsAny,
              value: <int>[rootId],
              hierarchyMatchMode: ObjectHierarchyMatchMode.isOrBelow,
            ).toJson(),
          ],
        },
      );

      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: GenericDatabasePage(
            repository: repository,
            databaseId: recipeTypeId,
            onDatabaseChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('親を直接付与'), findsOneWidget);
      expect(find.text('孫を直接付与'), findsOneWidget);
      expect(find.text('対象外'), findsNothing);

      await tester.tap(find.text('フィルター 1'));
      await tester.pumpAndSettle();

      expect(find.text('階層'), findsOneWidget);
      expect(find.text('配下を含む'), findsOneWidget);
    },
  );
}
