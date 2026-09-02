import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_graph_query_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('graph query resolves node metadata and backlink source metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );

    final tagType = await systemStore.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'tag',
      name: 'タグ',
      icon: '🏷️',
    );
    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: '書籍',
      icon: '📚',
    );
    final tagPropertyId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'タグ',
      targetObjectTypeId: tagType.id,
    );
    final bookType = (await objectStore.getObjectType(bookTypeId))!;
    final tagProperty = bookType.properties.firstWhere(
      (property) => property.id == tagPropertyId,
    );

    final tagId = await objectStore.createObject(
      objectTypeId: tagType.id,
      title: '数学',
    );
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: '数論講義',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: tagProperty,
      targetObjectIds: [tagId],
    );

    final graph = ObjectGraphQueryStore(genericStore);
    final node = await graph.getNode(tagId);
    final backlinks = await graph.backlinks(tagId);

    expect(node, isNotNull);
    expect(node!.objectTypeName, 'タグ');
    expect(node.objectTypeIcon, '🏷️');
    expect(node.isSystemType, true);
    expect(backlinks, hasLength(1));
    expect(backlinks.single.sourceObjectId, bookId);
    expect(backlinks.single.sourceTitle, '数論講義');
    expect(backlinks.single.sourceObjectTypeName, '書籍');
    expect(backlinks.single.propertyName, 'タグ');
  });
}
