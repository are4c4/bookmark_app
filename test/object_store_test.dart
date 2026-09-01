import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late int workspaceId;
  late ObjectStore store;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    workspaceId = await WorkspaceStore(database).initialize();
    store = ObjectStore(GenericDatabaseStore(database));
  });

  tearDown(() => database.close());

  test('generic database storage is exposed as object types and objects', () async {
    final bookTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
      icon: '📚',
    );
    await store.createProperty(
      objectTypeId: bookTypeId,
      name: 'Rating',
      type: ObjectPropertyType.rating,
    );
    await store.createObject(objectTypeId: bookTypeId, title: 'Number Theory');

    final type = await store.getObjectType(bookTypeId);
    final objects = await store.listObjects(bookTypeId);

    expect(type, isNotNull);
    expect(type!.name, 'Book');
    expect(type.kind, ObjectTypeKind.custom);
    expect(type.properties.single.type, ObjectPropertyType.rating);
    expect(objects.single.title, 'Number Theory');
    expect(objects.single.objectTypeId, bookTypeId);
  });

  test('typed relation links objects from the configured target type', () async {
    final bookTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    await store.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );

    final bookId = await store.createObject(
      objectTypeId: bookTypeId,
      title: 'Number Theory',
    );
    final authorId = await store.createObject(
      objectTypeId: personTypeId,
      title: 'Serre',
    );

    final bookType = (await store.getObjectType(bookTypeId))!;
    final authorProperty = bookType.properties.single;
    await store.setRelation(
      objectId: bookId,
      property: authorProperty,
      targetObjectIds: <int>[authorId],
    );

    final book = (await store.listObjects(bookTypeId)).single;
    final related = await store.resolveRelation(
      authorProperty,
      book.values[authorProperty.id],
    );

    expect(authorProperty.isRelation, isTrue);
    expect(authorProperty.targetObjectTypeId, personTypeId);
    expect(related.single.id, authorId);
    expect(related.single.title, 'Serre');
  });

  test('relation rejects objects from a different object type', () async {
    final bookTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Book',
    );
    final personTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Person',
    );
    final placeTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Place',
    );
    await store.createRelationProperty(
      objectTypeId: bookTypeId,
      name: 'Author',
      targetObjectTypeId: personTypeId,
      multiple: false,
    );

    final bookId = await store.createObject(
      objectTypeId: bookTypeId,
      title: 'Number Theory',
    );
    final placeId = await store.createObject(
      objectTypeId: placeTypeId,
      title: 'Paris',
    );
    final relation = (await store.getObjectType(bookTypeId))!.properties.single;

    expect(
      () => store.setRelation(
        objectId: bookId,
        property: relation,
        targetObjectIds: <int>[placeId],
      ),
      throwsArgumentError,
    );
  });

  test('self relation can represent a tag hierarchy', () async {
    final tagTypeId = await store.createObjectType(
      workspaceId: workspaceId,
      name: 'Tag',
      icon: '🏷️',
    );
    await store.createRelationProperty(
      objectTypeId: tagTypeId,
      name: 'Parent',
      targetObjectTypeId: tagTypeId,
      multiple: false,
    );

    final fruitId = await store.createObject(
      objectTypeId: tagTypeId,
      title: 'くだもの',
    );
    final appleId = await store.createObject(
      objectTypeId: tagTypeId,
      title: 'りんご',
    );
    final parentProperty = (await store.getObjectType(tagTypeId))!.properties.single;

    await store.setRelation(
      objectId: appleId,
      property: parentProperty,
      targetObjectIds: <int>[fruitId],
    );

    final apple = (await store.listObjects(tagTypeId))
        .singleWhere((object) => object.id == appleId);
    final parent = await store.resolveRelation(
      parentProperty,
      apple.values[parentProperty.id],
    );

    expect(parent.single.title, 'くだもの');
  });
}
