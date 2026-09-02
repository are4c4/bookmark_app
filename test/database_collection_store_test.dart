import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_collection_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
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
  });

  tearDown(() => database.close());

  test('legacy Database falls back to self ObjectType with no collection filter',
      () async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Legacy',
    );

    final definition = await collectionStore.readEffective(databaseId);

    expect(definition, isNotNull);
    expect(definition!.databaseId, databaseId);
    expect(definition.targetObjectTypeId, databaseId);
    expect(definition.collectionFilter, isEmpty);
    expect(definition.isLegacyFallback, isTrue);
  });

  test('persists target ObjectType and collection filter separately from Views',
      () async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '北海道旅行',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Place',
    );
    final prefectureId = await objectStore.createProperty(
      objectTypeId: targetTypeId,
      name: '都道府県',
      type: ObjectPropertyType.text,
    );

    await collectionStore.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: workspaceId,
        targetObjectTypeId: targetTypeId,
        collectionFilter: <ObjectFilterRule>[
          ObjectFilterRule(
            propertyId: prefectureId,
            operator: ObjectFilterOperator.equals,
            value: '北海道',
          ),
        ],
      ),
    );

    final definition = await collectionStore.readEffective(databaseId);
    expect(definition?.isLegacyFallback, isFalse);
    expect(definition?.targetObjectTypeId, targetTypeId);
    expect(definition?.collectionFilter, hasLength(1));
    expect(definition?.collectionFilter.single.propertyId, prefectureId);
    expect(
      definition?.collectionFilter.single.operator,
      ObjectFilterOperator.equals,
    );
    expect(definition?.collectionFilter.single.value, '北海道');
  });

  test('rejects collection filter Property from another ObjectType', () async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Collection',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final otherTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Other',
    );
    final foreignPropertyId = await objectStore.createProperty(
      objectTypeId: otherTypeId,
      name: 'Foreign',
      type: ObjectPropertyType.text,
    );

    await expectLater(
      collectionStore.write(
        DatabaseCollectionDefinition(
          databaseId: databaseId,
          workspaceId: workspaceId,
          targetObjectTypeId: targetTypeId,
          collectionFilter: <ObjectFilterRule>[
            ObjectFilterRule(
              propertyId: foreignPropertyId,
              operator: ObjectFilterOperator.equals,
              value: 'x',
            ),
          ],
        ),
      ),
      throwsArgumentError,
    );
  });

  test('clear restores backward-compatible legacy semantics', () async {
    final databaseId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Collection',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    await collectionStore.write(
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: workspaceId,
        targetObjectTypeId: targetTypeId,
      ),
    );

    await collectionStore.clear(databaseId);
    final definition = await collectionStore.readEffective(databaseId);

    expect(definition?.isLegacyFallback, isTrue);
    expect(definition?.targetObjectTypeId, databaseId);
  });
}
