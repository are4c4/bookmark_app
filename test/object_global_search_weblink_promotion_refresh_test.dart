import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/object_global_search_page.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Weblink promoted from Search-opened detail is searchable on return',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);

    final articleTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Article',
    );
    final urlPropertyId = await objectStore.createProperty(
      objectTypeId: articleTypeId,
      name: 'URL',
      type: ObjectPropertyType.url,
    );
    final urlProperty = (await objectStore.getObjectType(articleTypeId))!
        .properties
        .singleWhere((property) => property.id == urlPropertyId);
    final articleId = await objectStore.createObject(
      objectTypeId: articleTypeId,
      title: 'PromotionSourceOnly',
    );
    await objectStore.setPropertyValue(
      objectId: articleId,
      property: urlProperty,
      value: 'https://fresh-target.example/path',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ObjectGlobalSearchPage(
          store: store,
          workspaceId: workspaceId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'promotionsource');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    final sourceResult = find.byKey(
      ValueKey('object-global-search-result-$articleId'),
    );
    expect(sourceResult, findsOneWidget);
    await tester.tap(sourceResult);
    await tester.pumpAndSettle();
    expect(find.byType(ObjectInspectorPage), findsOneWidget);

    final promote = find.byKey(ValueKey('promote-weblink-$urlPropertyId'));
    expect(promote, findsOneWidget);
    await tester.ensureVisible(promote);
    await tester.tap(promote);
    await tester.pumpAndSettle();

    final refreshedArticleType =
        (await objectStore.getObjectType(articleTypeId))!;
    final weblinkRelation = refreshedArticleType.properties.singleWhere(
      (property) =>
          property.name == 'Weblink' &&
          property.type == ObjectPropertyType.objectRelation,
    );
    final article = (await objectStore.listObjects(articleTypeId)).single;
    final targetIds = ObjectRelationValue.fromJson(
      article.values[weblinkRelation.id],
    ).objectIds;
    expect(targetIds, hasLength(1));
    final targetId = targetIds.single;

    final weblinkType = await SystemObjectStore(
      database: database,
      objectStore: objectStore,
    ).getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'weblink',
    );
    expect(weblinkType, isNotNull);
    expect(
      (await objectStore.listObjects(weblinkType!.id))
          .map((object) => object.id),
      contains(targetId),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'fresh');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-global-search-result-$targetId')),
      findsOneWidget,
      reason:
          'detail-return focused refresh must insert the promoted Weblink target FTS row',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
  });
}
