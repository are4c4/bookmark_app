import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_body_store.dart';
import 'package:bookmark_app/data/object_computed_value_store.dart';
import 'package:bookmark_app/data/object_detail_content_loader.dart';
import 'package:bookmark_app/data/object_detail_relation_context_loader.dart';
import 'package:bookmark_app/data/object_detail_session_loader.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_service.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/relation_read_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail context resolves one Relation neighborhood', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);

    final bookTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final authorId = await objectStore.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
    );
    final author = (await objectStore.getObjectType(bookTypeId))!
        .properties
        .singleWhere((property) => property.id == authorId);
    final bookId = await objectStore.createObject(
      objectTypeId: bookTypeId,
      title: 'Book A',
    );
    final personId = await objectStore.createObject(
      objectTypeId: personTypeId,
      title: 'Alice',
    );
    await objectStore.setRelation(
      objectId: bookId,
      property: author,
      targetObjectIds: <int>[personId],
    );

    final loader = ObjectDetailRelationContextLoader(
      sessionLoader: ObjectDetailSessionLoader(
        contentLoader: ObjectDetailContentLoader(
          objectStore: objectStore,
          bodyStore: ObjectBodyStore(genericStore),
          computedStore: ObjectComputedValueStore(objectStore),
        ),
        defaultsService: ObjectTypeDefaultsService(store: defaultsStore),
        appFallback: const ObjectTypeDefaults(),
      ),
      relationReads: RelationReadService(objectStore),
    );

    final book = await loader.load(objectTypeId: bookTypeId, objectId: bookId);
    final person = await loader.load(
      objectTypeId: personTypeId,
      objectId: personId,
    );

    expect(book?.neighborhood.outgoing.single.property.id, authorId);
    expect(book?.outgoing.single.targetObject.title, 'Alice');
    expect(book?.backlinks, isEmpty);
    expect(person?.neighborhood.backlinks.single.property.id, authorId);
    expect(person?.backlinks.single.sourceObject.title, 'Book A');
    expect(person?.outgoing, isEmpty);
  });
}
