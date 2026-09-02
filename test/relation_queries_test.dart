import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/relation_queries.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filtered backlink and outgoing queries isolate one Relation Property', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = ObjectStore(GenericDatabaseStore(database));

    final bookTypeId = await store.createObjectType(workspaceId: workspaceId, name: 'Book');
    final personTypeId = await store.createObjectType(workspaceId: workspaceId, name: 'Person');
    await store.createRelationProperty(objectTypeId: bookTypeId, name: 'Author', targetObjectTypeId: personTypeId);
    await store.createRelationProperty(objectTypeId: bookTypeId, name: 'Editor', targetObjectTypeId: personTypeId);

    final properties = (await store.getObjectType(bookTypeId))!.properties;
    final author = properties.firstWhere((property) => property.name == 'Author');
    final editor = properties.firstWhere((property) => property.name == 'Editor');
    final bookId = await store.createObject(objectTypeId: bookTypeId, title: 'Book');
    final personId = await store.createObject(objectTypeId: personTypeId, title: 'Person');

    await store.setRelation(objectId: bookId, property: author, targetObjectIds: [personId]);
    await store.setRelation(objectId: bookId, property: editor, targetObjectIds: [personId]);

    final authorBacklinks = await store.backlinksForProperty(targetObjectId: personId, propertyId: author.id);
    final editorOutgoing = await store.outgoingRelationsForProperty(sourceObjectId: bookId, propertyId: editor.id);

    expect(authorBacklinks, hasLength(1));
    expect(authorBacklinks.single.sourceObjectId, bookId);
    expect(authorBacklinks.single.propertyId, author.id);
    expect(editorOutgoing, hasLength(1));
    expect(editorOutgoing.single.targetObjectId, personId);
    expect(editorOutgoing.single.propertyId, editor.id);
  });
}
