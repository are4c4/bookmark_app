import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_index_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace rebuild indexes legacy Relation values idempotently', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final indexService = RelationIndexService(objectStore);

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
    final relation =
        (await objectStore.getObjectType(bookTypeId))!.properties.single;
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Person',
    );

    // Simulate a legacy value written before normalized Relation edges existed.
    await genericStore.setValue(
      recordId: bookId,
      propertyId: relation.id,
      value: [personId],
    );

    expect(await objectStore.backlinks(personId), isEmpty);

    await indexService.rebuildWorkspace(workspaceId);
    await indexService.rebuildWorkspace(workspaceId);

    final backlinks = await objectStore.backlinks(personId);
    expect(backlinks, hasLength(1));
    expect(backlinks.single.sourceObjectId, bookId);
    expect(backlinks.single.propertyId, relation.id);
    expect(backlinks.single.targetObjectId, personId);
  });
}
