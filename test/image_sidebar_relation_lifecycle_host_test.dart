import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'exposed Images host shows Weblink backlinks and deletes Relation-safely',
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
      final defaultsStore = ObjectTypeDefaultsStore(genericStore);
      final schema = await WeblinkImageSchemaService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      ).ensureDefinition(workspaceId);
      final weblinkService = WeblinkObjectService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      );
      final imageService = ImageObjectService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      );
      final weblink = await weblinkService.findOrCreate(
        workspaceId: workspaceId,
        url: 'https://example.com/article',
      );
      final firstImage = await imageService.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/first.jpg',
        sourceUrl: 'https://cdn.example.com/first.jpg',
        title: 'First image',
      );
      final secondImage = await imageService.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/second.jpg',
        sourceUrl: 'https://cdn.example.com/second.jpg',
        title: 'Second image',
      );
      final bidirectionalStore = BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      );
      final mutations = RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
        genericStore: genericStore,
      );
      await mutations.setRelation(
        objectId: weblink.id,
        property: schema.representativeImageProperty,
        targetObjectIds: <int>[firstImage.id],
      );
      await mutations.setRelation(
        objectId: weblink.id,
        property: schema.relatedImagesProperty,
        targetObjectIds: <int>[firstImage.id, secondImage.id],
      );

      final navigation = await genericStore.listDatabases(workspaceId);
      final destination = navigation.singleWhere(
        (database) => database.id == schema.imageObjectTypeId,
      );
      expect(destination.name, 'Images');
      expect(await objectStore.backlinks(firstImage.id), hasLength(2));

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: GenericDatabasePage(
            repository: repository,
            databaseId: destination.id,
            onDatabaseChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(firstImage.title).first);
      await tester.pumpAndSettle();
      expect(find.text('Backlinks  2'), findsOneWidget);
      expect(find.text(weblink.title), findsWidgets);

      await tester.tap(find.byTooltip('削除'));
      await tester.pumpAndSettle();

      final images = await objectStore.listObjects(schema.imageObjectTypeId);
      expect(images.map((object) => object.id), isNot(contains(firstImage.id)));
      expect(images.map((object) => object.id), contains(secondImage.id));

      final survivingWeblink = (await objectStore.listObjects(
        schema.weblinkObjectTypeId,
      ))
          .singleWhere((object) => object.id == weblink.id);
      expect(
        ObjectRelationValue.fromJson(
          survivingWeblink.values[schema.representativeImageProperty.id],
        ).objectIds,
        isEmpty,
      );
      expect(
        ObjectRelationValue.fromJson(
          survivingWeblink.values[schema.relatedImagesProperty.id],
        ).objectIds,
        <int>[secondImage.id],
      );
      expect(await objectStore.backlinks(firstImage.id), isEmpty);
      expect(await objectStore.backlinks(secondImage.id), hasLength(1));

      final remainingEdges = await objectStore.outgoingRelations(weblink.id);
      expect(
        remainingEdges.where(
          (edge) => edge.propertyId == schema.representativeImageProperty.id,
        ),
        isEmpty,
      );
      final related = remainingEdges
          .where((edge) => edge.propertyId == schema.relatedImagesProperty.id)
          .toList(growable: false);
      expect(related, hasLength(1));
      expect(related.single.targetObjectId, secondImage.id);

      final integrity = RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
