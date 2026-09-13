import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_redirect_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_body.dart';
import 'package:bookmark_app/domain/object_merge_contract.dart';
import 'package:bookmark_app/domain/object_merge_state_materializer.dart';
import 'package:bookmark_app/domain/object_merge_state_planner.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_merge_review_dialog.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Inspector explicitly merges duplicate into current Object', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final typeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Book',
    );
    final currentId = await fixture.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Serre',
    );
    final candidateId = await fixture.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Serre',
    );

    await fixture.pumpInspector(tester, currentId);
    await _openMergeReview(tester, candidateId);

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('object-merge-review-submit')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('object-merge-review-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Objectを統合しますか？'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object-merge-confirm-submit')));
    await tester.pumpAndSettle();

    expect(
      await _objectById(fixture.objectStore, typeId, currentId),
      isNotNull,
    );
    expect(await _objectById(fixture.objectStore, typeId, candidateId), isNull);
    expect(
      await ObjectRedirectStore(fixture.genericStore).resolve(candidateId),
      currentId,
    );
    expect(
      find.byKey(const ValueKey('object-merge-review-dialog')),
      findsNothing,
    );
  });

  testWidgets(
    'Inspector can keep candidate identity and replace retired route',
    (tester) async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.close);
      final typeId = await fixture.objectStore.createObjectType(
        workspaceId: fixture.workspaceId,
        name: 'Topic',
      );
      final currentId = await fixture.objectStore.createObject(
        objectTypeId: typeId,
        title: 'Shared',
      );
      final candidateId = await fixture.objectStore.createObject(
        objectTypeId: typeId,
        title: 'Shared',
      );

      await fixture.pumpInspector(tester, currentId);
      await _openMergeReview(tester, candidateId);

      await tester.tap(
        find.byKey(const ValueKey('object-merge-survivor-candidate')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('object-merge-review-submit')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(
        find.byKey(const ValueKey('object-merge-review-submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('object-merge-confirm-submit')),
      );
      await tester.pumpAndSettle();

      expect(await _objectById(fixture.objectStore, typeId, currentId), isNull);
      expect(
        await _objectById(fixture.objectStore, typeId, candidateId),
        isNotNull,
      );
      expect(
        await ObjectRedirectStore(fixture.genericStore).resolve(currentId),
        candidateId,
      );
      expect(fixture.visitedObjectIds, contains(candidateId));
    },
  );

  testWidgets(
    'review and destructive confirmation cancellation do not mutate',
    (tester) async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.close);
      final typeId = await fixture.objectStore.createObjectType(
        workspaceId: fixture.workspaceId,
        name: 'Topic',
      );
      final currentId = await fixture.objectStore.createObject(
        objectTypeId: typeId,
        title: 'Same',
      );
      final candidateId = await fixture.objectStore.createObject(
        objectTypeId: typeId,
        title: 'Same',
      );

      await fixture.pumpInspector(tester, currentId);
      await _openMergeReview(tester, candidateId);

      await tester.tap(
        find.byKey(const ValueKey('object-merge-review-submit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('object-merge-confirm-cancel')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('object-merge-review-dialog')),
        findsOneWidget,
      );
      expect(
        await _objectById(fixture.objectStore, typeId, currentId),
        isNotNull,
      );
      expect(
        await _objectById(fixture.objectStore, typeId, candidateId),
        isNotNull,
      );

      await tester.tap(
        find.byKey(const ValueKey('object-merge-review-cancel')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('object-merge-review-dialog')),
        findsNothing,
      );
      expect(
        await _objectById(fixture.objectStore, typeId, currentId),
        isNotNull,
      );
      expect(
        await _objectById(fixture.objectStore, typeId, candidateId),
        isNotNull,
      );
    },
  );

  testWidgets('stale finalization fails closed and preserves both Objects', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.close);
    final typeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Topic',
    );
    final currentId = await fixture.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Stable',
    );
    final candidateId = await fixture.objectStore.createObject(
      objectTypeId: typeId,
      title: 'Stable',
    );

    await fixture.pumpInspector(tester, currentId);
    await _openMergeReview(tester, candidateId);

    await fixture.objectStore.renameObject(
      candidateId,
      'Changed during review',
    );

    await tester.tap(find.byKey(const ValueKey('object-merge-review-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('object-merge-confirm-submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('object-merge-review-error')),
      findsOneWidget,
    );
    expect(
      await _objectById(fixture.objectStore, typeId, currentId),
      isNotNull,
    );
    expect(
      (await _objectById(fixture.objectStore, typeId, candidateId))?.title,
      'Changed during review',
    );
  });

  testWidgets('merge review requires every unresolved A-owned decision', (
    tester,
  ) async {
    final prepared = _prepared(
      survivorTitle: 'Current',
      retiredTitle: 'Candidate',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectMergeReviewDialog(
            currentObjectId: 1,
            currentTitle: 'Current',
            candidateObjectId: 2,
            candidateTitle: 'Candidate',
            propertyNames: const <int, String>{},
            onPrepare: ({
              required survivorObjectId,
              required retiredObjectId,
            }) async => prepared,
            onFinalize: ({required prepared, required plan}) async => 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('object-merge-review-submit')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('object-merge-decision-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('残す側「Current」を採用').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('object-merge-review-submit')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Relation blockers are visible and disable merge execution', (
    tester,
  ) async {
    final prepared = _prepared(
      survivorTitle: 'Same',
      retiredTitle: 'Same',
      relationBlockers: <ObjectMergeRelationBlocker>[
        ObjectMergeRelationBlocker(
          key: 'relation:cardinality',
          reason: '単一Relationのcardinalityが競合しています。',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectMergeReviewDialog(
            currentObjectId: 1,
            currentTitle: 'Same',
            candidateObjectId: 2,
            candidateTitle: 'Same',
            propertyNames: const <int, String>{},
            onPrepare: ({
              required survivorObjectId,
              required retiredObjectId,
            }) async => prepared,
            onFinalize: ({required prepared, required plan}) async => 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Relationの競合'), findsOneWidget);
    expect(find.text('単一Relationのcardinalityが競合しています。'), findsOneWidget);
    expect(find.text('relation:cardinality'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('object-merge-review-submit')),
          )
          .onPressed,
      isNull,
    );
  });
}

Future<void> _openMergeReview(WidgetTester tester, int candidateId) async {
  final mergeButton = find.byKey(
    ValueKey('object-duplicate-merge-$candidateId'),
  );
  expect(mergeButton, findsOneWidget);
  await tester.tap(mergeButton);
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('object-merge-review-dialog')),
    findsOneWidget,
  );
}

ObjectMergePreparedState _prepared({
  required String survivorTitle,
  required String retiredTitle,
  List<ObjectMergeRelationBlocker> relationBlockers =
      const <ObjectMergeRelationBlocker>[],
}) {
  return ObjectMergePreparedState.prepare(
    survivor: ObjectMergeStateSnapshot(
      objectId: 1,
      objectTypeId: 10,
      title: survivorTitle,
      propertySnapshots: const <ObjectMergeValuePropertySnapshot>[],
      body: const ObjectBodyDocument(),
      aliases: const <String>[],
    ),
    retired: ObjectMergeStateSnapshot(
      objectId: 2,
      objectTypeId: 10,
      title: retiredTitle,
      propertySnapshots: const <ObjectMergeValuePropertySnapshot>[],
      body: const ObjectBodyDocument(),
      aliases: const <String>[],
    ),
    relationBlockers: relationBlockers,
  );
}

Future<AppObject?> _objectById(
  ObjectStore store,
  int objectTypeId,
  int objectId,
) async {
  for (final object in await store.listObjects(objectTypeId)) {
    if (object.id == objectId) return object;
  }
  return null;
}

class _Fixture {
  _Fixture({
    required this.database,
    required this.workspaceId,
    required this.genericStore,
    required this.objectStore,
  });

  final AppDatabase database;
  final int workspaceId;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final List<int> visitedObjectIds = <int>[];

  static Future<_Fixture> create() async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    return _Fixture(
      database: database,
      workspaceId: workspaceId,
      genericStore: genericStore,
      objectStore: objectStore,
    );
  }

  Future<void> pumpInspector(WidgetTester tester, int objectId) async {
    visitedObjectIds.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: objectId,
          onObjectVisited: visitedObjectIds.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close() => database.close();
}
