import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/canonical_object_mutation_impact_sink.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/person_object_bridge.dart';
import 'package:bookmark_app/data/person_object_write_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/repositories/object_global_search_service.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'generic Inspector Person title and Note edits refresh canonical Search',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final genericStore = GenericDatabaseStore(database);
      final search = ObjectGlobalSearchService(genericStore);
      final workspaceId = await WorkspaceStore(
        database,
        canonicalObjectMutationImpactSink: CanonicalObjectMutationImpactSink(
          onObjectCommitted: search.refreshObjectLabelDependents,
          onDeletionCommitted: (impact) =>
              search.refreshCommittedDeletionImpact(
            deletedObjectId: impact.deletedObjectId,
            changedSourceObjectIds: impact.detachedSourceObjectIds,
          ),
        ),
      ).initialize();
      final objectStore = ObjectStore(genericStore);
      final bridge = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
      );
      final personId = await PersonObjectWriteService.forDatabase(database)
          .create(
            workspaceId: workspaceId,
            name: 'InspectorBeforeToken',
            note: 'InspectorOldNoteToken',
          );
      final schema = await bridge.ensurePersonObjectType(workspaceId);
      final objectId = (await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      ))!;
      await search.rebuildWorkspace(workspaceId);

      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'InspectorBeforeToken',
        )).map((hit) => hit.object.id),
        <int>[objectId],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ObjectInspectorPage(
            store: genericStore,
            objectStore: objectStore,
            objectId: objectId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('object-title-edit-button')),
        findsOneWidget,
      );
      final noteEdit = find.byKey(
        ValueKey('edit-object-value-${schema.noteProperty.id}'),
      );
      expect(noteEdit, findsOneWidget);

      final renameProjection = search.projectionChanges.first;
      await tester.tap(find.byKey(const ValueKey('object-title-edit-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('object-title-edit-field')),
        'InspectorAfterToken',
      );
      await tester.tap(find.byKey(const ValueKey('object-title-edit-save')));
      await tester.pumpAndSettle();
      await renameProjection;

      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'InspectorBeforeToken',
        ),
        isEmpty,
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'InspectorAfterToken',
        )).map((hit) => hit.object.id),
        <int>[objectId],
      );

      final noteProjection = search.projectionChanges.first;
      await tester.ensureVisible(noteEdit);
      await tester.tap(noteEdit);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(
          ValueKey('object-value-edit-field-${schema.noteProperty.id}'),
        ),
        'InspectorNewNoteToken',
      );
      await tester.tap(
        find.byKey(
          ValueKey('object-value-edit-save-${schema.noteProperty.id}'),
        ),
      );
      await tester.pumpAndSettle();
      await noteProjection;

      expect(
        await search.search(
          workspaceId: workspaceId,
          rawQuery: 'InspectorOldNoteToken',
        ),
        isEmpty,
      );
      expect(
        (await search.search(
          workspaceId: workspaceId,
          rawQuery: 'InspectorNewNoteToken',
        )).map((hit) => hit.object.id),
        <int>[objectId],
      );

      final object = (await objectStore.listObjects(schema.objectType.id))
          .single;
      final person = (await database.select(database.people).get()).single;
      expect(object.title, 'InspectorAfterToken');
      expect(object.values[schema.noteProperty.id], 'InspectorNewNoteToken');
      expect(person.name, 'InspectorAfterToken');
      expect(person.note, 'InspectorNewNoteToken');
    },
  );

  testWidgets(
    'generic Person Inspector hides persistence errors and fails closed',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final bridge = PersonObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: SystemObjectStore(
          database: database,
          objectStore: objectStore,
        ),
      );
      final personId = await PersonObjectWriteService.forDatabase(
        database,
      ).create(workspaceId: workspaceId, name: 'Preserved', note: 'old note');
      final schema = await bridge.ensurePersonObjectType(workspaceId);
      final objectId = (await bridge.objectIdForLegacyPerson(
        workspaceId,
        personId,
      ))!;

      await tester.pumpWidget(
        MaterialApp(
          home: ObjectInspectorPage(
            store: genericStore,
            objectStore: objectStore,
            objectId: objectId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await database.customStatement(
        'DELETE FROM person_object_links WHERE workspace_id = ? AND person_id = ?',
        <Object>[workspaceId, personId],
      );

      await tester.tap(find.byKey(const ValueKey('object-title-edit-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('object-title-edit-field')),
        'Must not commit',
      );
      await tester.tap(find.byKey(const ValueKey('object-title-edit-save')));
      await tester.pumpAndSettle();

      expect(find.text('人物を更新できませんでした。'), findsOneWidget);
      final object = (await objectStore.listObjects(schema.objectType.id))
          .single;
      final person = (await database.select(database.people).get()).single;
      expect(object.title, 'Preserved');
      expect(object.values[schema.noteProperty.id], 'old note');
      expect(person.name, 'Preserved');
      expect(person.note, 'old note');
    },
  );
}
