import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Relation-safe Object delete rolls back all detachments if final delete fails',
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

    final sourceTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Source',
    );
    final targetTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Target',
    );
    final relationId = await objectStore.createRelationProperty(
      objectTypeId: sourceTypeId,
      name: 'Target',
      targetObjectTypeId: targetTypeId,
      multiple: false,
    );
    final relation = (await objectStore.getObjectType(sourceTypeId))!
        .properties
        .singleWhere((property) => property.id == relationId);

    final sourceA = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'A',
    );
    final sourceB = await objectStore.createObject(
      objectTypeId: sourceTypeId,
      title: 'B',
    );
    final target = await objectStore.createObject(
      objectTypeId: targetTypeId,
      title: 'Target',
    );
    await objectStore.setRelation(
      objectId: sourceA,
      property: relation,
      targetObjectIds: <int>[target],
    );
    await objectStore.setRelation(
      objectId: sourceB,
      property: relation,
      targetObjectIds: <int>[target],
    );

    // Force the failure after every incoming Relation has already been detached.
    // The RelationMutationService outer transaction must restore those earlier
    // writes when the final target-row deletion aborts.
    await database.customStatement('''
      CREATE TRIGGER fail_relation_safe_target_delete
      BEFORE DELETE ON generic_records
      WHEN OLD.id = $target
      BEGIN
        SELECT RAISE(ABORT, 'forced target delete failure');
      END
    ''');

    await expectLater(
      service.deleteObject(
        workspaceId: workspaceId,
        objectTypeId: targetTypeId,
        objectId: target,
      ),
      throwsA(anything),
    );

    expect(
      (await objectStore.listObjects(targetTypeId)).map((object) => object.id),
      contains(target),
    );
    final sources = await objectStore.listObjects(sourceTypeId);
    expect(sources, hasLength(2));
    for (final source in sources) {
      expect(
        ObjectRelationValue.fromJson(source.values[relationId]).objectIds,
        <int>[target],
      );
    }
    final backlinks = await objectStore.backlinks(target);
    expect(backlinks, hasLength(2));
    expect(
      backlinks.map((edge) => edge.sourceObjectId).toSet(),
      <int>{sourceA, sourceB},
    );
  });
}
