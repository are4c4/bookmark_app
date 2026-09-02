import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/database_collection_definition.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/generic_database_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fixture {
  _Fixture({
    required this.database,
    required this.repository,
    required this.genericStore,
    required this.objectStore,
    required this.collectionStore,
    required this.workspaceId,
  });

  final AppDatabase database;
  final BookmarkRepository repository;
  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;
  final DatabaseCollectionStore collectionStore;
  final int workspaceId;
}

Future<_Fixture> _fixture() async {
  final database = AppDatabase.forTesting(NativeDatabase.memory());
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
  return _Fixture(
    database: database,
    repository: repository,
    genericStore: genericStore,
    objectStore: objectStore,
    collectionStore: DatabaseCollectionStore(
      genericStore: genericStore,
      objectStore: objectStore,
    ),
    workspaceId: workspaceId,
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  _Fixture fixture,
  int databaseId,
) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: GenericDatabasePage(
        repository: fixture.repository,
        databaseId: databaseId,
        onDatabaseChanged: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openRelation(
  WidgetTester tester, {
  required String objectTitle,
  required String propertyName,
}) async {
  await tester.tap(find.text(objectTitle).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(propertyName).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('real page bidirectional save synchronizes inverse Relation',
      (tester) async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final databaseId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: '本棚',
    );
    final bookTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Book',
    );
    final personTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Person',
    );
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: fixture.genericStore,
      objectStore: fixture.objectStore,
    );
    final pair = await bidirectionalStore.createPair(
      sourceObjectTypeId: bookTypeId,
      sourceName: 'Authors',
      targetObjectTypeId: personTypeId,
      inverseName: 'Books',
    );
    final bookId = await fixture.objectStore.createObject(
      objectTypeId: bookTypeId,
      title: '数論講義',
    );
    final personId = await fixture.objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Serre',
    );
    await fixture.collectionStore.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: fixture.workspaceId,
        targetObjectTypeId: bookTypeId,
      ),
    );

    await _pumpPage(tester, fixture, databaseId);
    await _openRelation(
      tester,
      objectTitle: '数論講義',
      propertyName: 'Authors',
    );
    await tester.tap(find.text('Serre'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final book = (await fixture.objectStore.listObjects(bookTypeId)).single;
    final person = (await fixture.objectStore.listObjects(personTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[pair.sourceProperty.id]).objectIds,
      <int>[personId],
    );
    expect(
      ObjectRelationValue.fromJson(person.values[pair.inverseProperty.id]).objectIds,
      <int>[bookId],
    );
  });

  testWidgets('real page exposes missing target without mutating on cancel',
      (tester) async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final databaseId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: '本棚',
    );
    final bookTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Book',
    );
    final personTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Person',
    );
    final relationId = await fixture.objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    final bookId = await fixture.objectStore.createObject(
      objectTypeId: bookTypeId,
      title: '数論講義',
    );
    const missingId = 999999;
    await fixture.genericStore.setValue(
      recordId: bookId,
      propertyId: relationId,
      value: const <String, dynamic>{'objectIds': <int>[missingId]},
    );
    await fixture.collectionStore.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: fixture.workspaceId,
        targetObjectTypeId: bookTypeId,
      ),
    );

    await _pumpPage(tester, fixture, databaseId);
    await _openRelation(
      tester,
      objectTitle: '数論講義',
      propertyName: 'Author',
    );
    expect(find.text('見つからないObject: $missingId'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    final book = (await fixture.objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[relationId]).objectIds,
      <int>[missingId],
    );
  });

  testWidgets('real page diagnoses single-Relation cardinality without mutation',
      (tester) async {
    final fixture = await _fixture();
    addTearDown(fixture.database.close);
    final databaseId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: '本棚',
    );
    final bookTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Book',
    );
    final personTypeId = await fixture.objectStore.createObjectType(
      workspaceId: fixture.workspaceId,
      name: 'Person',
    );
    final relationId = await fixture.objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );
    final bookId = await fixture.objectStore.createObject(
      objectTypeId: bookTypeId,
      title: '数論講義',
    );
    final firstId = await fixture.objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Alice',
    );
    final secondId = await fixture.objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Bob',
    );
    await fixture.genericStore.setValue(
      recordId: bookId,
      propertyId: relationId,
      value: <String, dynamic>{'objectIds': <int>[firstId, secondId]},
    );
    await fixture.collectionStore.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: fixture.workspaceId,
        targetObjectTypeId: bookTypeId,
      ),
    );

    await _pumpPage(tester, fixture, databaseId);
    await _openRelation(
      tester,
      objectTitle: '数論講義',
      propertyName: 'Author',
    );
    expect(
      find.text('単一Relationに複数の値が保存されています。明示的に選び直して保存してください。'),
      findsOneWidget,
    );
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    final book = (await fixture.objectStore.listObjects(bookTypeId)).single;
    expect(
      ObjectRelationValue.fromJson(book.values[relationId]).objectIds,
      <int>[firstId, secondId],
    );
  });
}
