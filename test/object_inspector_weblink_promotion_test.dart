import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Object detail promotes URL to reusable Weblink and keeps source',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);

    final typeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Article',
    );
    final urlPropertyId = await objectStore.createProperty(
      objectTypeId: typeId,
      name: 'URL',
      type: ObjectPropertyType.url,
    );
    final urlProperty = (await objectStore.getObjectType(typeId))!
        .properties
        .singleWhere((property) => property.id == urlPropertyId);
    final objectId = await objectStore.createObject(
      objectTypeId: typeId,
      title: 'Example article',
    );
    await objectStore.setPropertyValue(
      objectId: objectId,
      property: urlProperty,
      value: 'https://example.com/path',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: objectId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(ValueKey('promote-weblink-$urlPropertyId'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();

    final source = (await objectStore.listObjects(typeId)).single;
    expect(source.values[urlPropertyId], 'https://example.com/path');

    final refreshedType = (await objectStore.getObjectType(typeId))!;
    final relation = refreshedType.properties.singleWhere(
      (property) =>
          property.name == 'Weblink' &&
          property.type == ObjectPropertyType.objectRelation,
    );
    final relatedIds = ObjectRelationValue.fromJson(source.values[relation.id])
        .objectIds;
    expect(relatedIds, hasLength(1));

    final weblinkType = await SystemObjectStore(
      database: database,
      objectStore: objectStore,
    ).getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'weblink',
    );
    expect(weblinkType, isNotNull);
    final weblinks = await objectStore.listObjects(weblinkType!.id);
    expect(weblinks.map((object) => object.id), contains(relatedIds.single));
  });
}
