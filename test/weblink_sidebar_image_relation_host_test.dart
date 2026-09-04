import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_integrity_service.dart';
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
    'exposed Weblinks host edits production Image Relations canonically',
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
      final defaultsStore = ObjectTypeDefaultsStore(genericStore);
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final schema = await WeblinkImageSchemaService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      ).ensureDefinition(workspaceId);
      final weblinks = WeblinkObjectService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      );
      final images = ImageObjectService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      );
      final weblink = await weblinks.findOrCreate(
        workspaceId: workspaceId,
        url: 'https://example.com/article',
      );
      final firstImage = await images.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/cover-a.jpg',
        sourceUrl: 'https://cdn.example.com/cover-a.jpg',
        title: 'Cover A',
      );
      final secondImage = await images.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/related-b.jpg',
        sourceUrl: 'https://cdn.example.com/related-b.jpg',
        title: 'Related B',
      );

      final navigation = await genericStore.listDatabases(workspaceId);
      final weblinkDestination = navigation.singleWhere(
        (database) => database.id == schema.weblinkObjectTypeId,
      );
      expect(weblinkDestination.name, 'Weblinks');

      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: GenericDatabasePage(
            repository: repository,
            databaseId: weblinkDestination.id,
            onDatabaseChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(weblink.title).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text(WeblinkImageSchemaService.representativeImageName).last);
      await tester.pumpAndSettle();
      var dialog = find.byType(AlertDialog);
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Cover A')),
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('保存')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(WeblinkImageSchemaService.relatedImagesName).last);
      await tester.pumpAndSettle();
      dialog = find.byType(AlertDialog);
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Cover A')),
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Related B')),
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('保存')),
      );
      await tester.pumpAndSettle();

      final persisted =
          (await objectStore.listObjects(schema.weblinkObjectTypeId))
              .singleWhere((object) => object.id == weblink.id);
      expect(
        ObjectRelationValue.fromJson(
          persisted.values[schema.representativeImageProperty.id],
        ).objectIds,
        <int>[firstImage.id],
      );
      expect(
        ObjectRelationValue.fromJson(
          persisted.values[schema.relatedImagesProperty.id],
        ).objectIds,
        <int>[firstImage.id, secondImage.id],
      );

      final edges = await objectStore.outgoingRelations(weblink.id);
      expect(
        edges.where(
          (edge) => edge.propertyId == schema.representativeImageProperty.id,
        ),
        hasLength(1),
      );
      expect(
        edges.where(
          (edge) => edge.propertyId == schema.relatedImagesProperty.id,
        ),
        hasLength(2),
      );
      expect(await objectStore.backlinks(firstImage.id), hasLength(2));
      expect(await objectStore.backlinks(secondImage.id), hasLength(1));

      final integrity = RelationIntegrityService(
        objectStore: objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
      );
      expect((await integrity.auditWorkspace(workspaceId)).isHealthy, isTrue);
    },
  );
}
