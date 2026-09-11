import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_group_object_convergence_service.dart';
import 'package:bookmark_app/data/person_group_object_write_service.dart';
import 'package:bookmark_app/data/person_group_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/relation_target_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/people_management_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BookmarkRepository> _repository(AppDatabase database) async {
  final workspaceStore = WorkspaceStore(database);
  final workspaceId = await workspaceStore.initialize();
  final lifecycleStore = BookmarkLifecycleStore(database);
  await lifecycleStore.initialize();
  return BookmarkRepository(
    database,
    workspaceStore: workspaceStore,
    lifecycleStore: lifecycleStore,
    workspaceId: workspaceId,
  );
}

Future<void> _openGroupManager(WidgetTester tester) async {
  await tester.tap(find.byTooltip('人物グループ'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('グループを管理…'));
  await tester.pumpAndSettle();
}

Finder _personMenu() =>
    find.byWidgetPredicate((widget) => widget is PopupMenuButton<String>);

void main() {
  testWidgets(
    'People group UI keeps canonical Objects/Relations and legacy projection equivalent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = await _repository(database);
      final personId = await repository.createPerson('Ada Lovelace');

      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final systemObjectStore = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final personBridge = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjectStore,
      );
      final convergence = PersonGroupObjectConvergenceService(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjectStore,
        personBridge: personBridge,
      );
      final schema = await convergence.ensureSchema(repository.workspaceId);
      final legacyGroups = PersonGroupStore(database);

      await tester.pumpWidget(
        MaterialApp(home: PeopleManagementPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      await _openGroupManager(tester);
      final manager = find.byType(AlertDialog);
      final createField = find.descendant(
        of: manager,
        matching: find.byType(TextField),
      );
      expect(createField, findsOneWidget);
      await tester.enterText(createField, 'Research');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final createdLegacy = (await legacyGroups.listGroups()).single;
      expect(createdLegacy.name, 'Research');
      final createdCanonical = (await objectStore.listObjects(
        schema.groupObjectType.id,
      )).single;
      expect(createdCanonical.title, 'Research');
      expect(
        createdCanonical.values[schema.legacyGroupIdProperty.id],
        createdLegacy.id,
      );

      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();

      await tester.tap(_personMenu().last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('所属グループを編集'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research'));
      await tester.pumpAndSettle();

      expect(
        (await legacyGroups.groupsForPerson(personId))
            .map((group) => group.id)
            .toList(),
        [createdLegacy.id],
      );
      final personObjectId = await personBridge.objectIdForLegacyPerson(
        repository.workspaceId,
        personId,
      );
      expect(personObjectId, isNotNull);
      final canonicalPersonId = personObjectId!;
      final relationTargets = RelationTargetService(objectStore);
      final selectedAfterAdd = await relationTargets.selectionForMutation(
        workspaceId: repository.workspaceId,
        sourceObjectId: canonicalPersonId,
        property: schema.personGroupsProperty,
      );
      expect(selectedAfterAdd.selectedObjectIds, [createdCanonical.id]);

      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();
      await _openGroupManager(tester);

      final groupName = find.text('Research');
      await tester.tap(groupName);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(groupName);
      await tester.pump();
      final renameField = find.byKey(const ValueKey('inline-rename-field'));
      expect(renameField, findsOneWidget);
      await tester.enterText(renameField, 'Analytical Engine');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final renamedLegacy = (await legacyGroups.listGroups()).single;
      expect(renamedLegacy.name, 'Analytical Engine');
      final renamedCanonical = (await objectStore.listObjects(
        schema.groupObjectType.id,
      )).single;
      expect(renamedCanonical.id, createdCanonical.id);
      expect(renamedCanonical.title, 'Analytical Engine');

      final deleteButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byTooltip('削除'),
      );
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(await legacyGroups.listGroups(), isEmpty);
      expect(await legacyGroups.groupsForPerson(personId), isEmpty);
      expect(await objectStore.listObjects(schema.groupObjectType.id), isEmpty);
      final selectedAfterDelete = await relationTargets.selectionForMutation(
        workspaceId: repository.workspaceId,
        sourceObjectId: canonicalPersonId,
        property: schema.personGroupsProperty,
      );
      expect(selectedAfterDelete.selectedObjectIds, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'People group UI fails closed with a stable message on canonical conflict',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = await _repository(database);
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final systemObjectStore = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final personBridge = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjectStore,
      );
      final convergence = PersonGroupObjectConvergenceService(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjectStore,
        personBridge: personBridge,
      );
      final schema = await convergence.ensureSchema(repository.workspaceId);
      final groupWrites = PersonGroupObjectWriteService(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemObjectStore,
        personBridge: personBridge,
      );
      final legacyGroups = PersonGroupStore(database);
      final created = await groupWrites.create(
        workspaceId: repository.workspaceId,
        name: 'Research',
      );
      await objectStore.renameObject(
        created.canonicalObjectId,
        'Conflicting canonical title',
      );

      await tester.pumpWidget(
        MaterialApp(home: PeopleManagementPage(repository: repository)),
      );
      await tester.pumpAndSettle();
      await _openGroupManager(tester);

      final deleteButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byTooltip('削除'),
      );
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(
        find.text('人物グループを更新できませんでした。状態を確認してもう一度お試しください。'),
        findsOneWidget,
      );
      final legacy = (await legacyGroups.listGroups()).single;
      expect(legacy.id, created.legacyGroupId);
      expect(legacy.name, 'Research');
      final canonical = (await objectStore.listObjects(
        schema.groupObjectType.id,
      )).single;
      expect(canonical.id, created.canonicalObjectId);
      expect(canonical.title, 'Conflicting canonical title');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
