import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'deletion impact reports the target when there are no backlinks',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final service = RelationMutationService(
        objectStore: objectStore,
        bidirectionalStore: BidirectionalRelationStore(
          genericStore: genericStore,
          objectStore: objectStore,
        ),
        genericStore: genericStore,
      );
      final personTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Person',
      );
      final personId = await objectStore.createObject(
        objectTypeId: personTypeId,
        title: 'Person',
      );

      final impact = await service.deleteObjectWithImpact(
        workspaceId: workspaceId,
        objectTypeId: personTypeId,
        objectId: personId,
      );

      expect(impact.deletedObjectId, personId);
      expect(impact.detachedSourceObjectIds, isEmpty);
      expect(await objectStore.listObjects(personTypeId), isEmpty);
    },
  );

  test('deletion impact reports each changed Relation source once', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final service = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
      genericStore: genericStore,
    );
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Authors',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Editors',
      targetObjectTypeId: personTypeId,
      multiple: true,
    );
    final properties = (await objectStore.getObjectType(bookTypeId))!
        .properties;
    final authors = properties.firstWhere(
      (property) => property.name == 'Authors',
    );
    final editors = properties.firstWhere(
      (property) => property.name == 'Editors',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final otherBookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Other Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: authors,
      targetObjectIds: [personId],
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: editors,
      targetObjectIds: [personId],
    );
    await objectStore.setRelation(
      objectId: otherBookId,
      property: authors,
      targetObjectIds: [personId],
    );

    final impact = await service.deleteObjectWithImpact(
      workspaceId: workspaceId,
      objectTypeId: personTypeId,
      objectId: personId,
    );

    expect(impact.deletedObjectId, personId);
    expect(impact.detachedSourceObjectIds, [bookId, otherBookId]);
  });
}
