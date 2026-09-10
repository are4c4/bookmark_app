import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/views/home_start_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Home creates and reuses canonical Weblinks from pointer and keyboard submit',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final store = GenericDatabaseStore(database);
      final objectStore = ObjectStore(store);
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final weblinks = WeblinkObjectService(
        systemObjects: systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(store),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeStartPage(store: store, workspaceId: workspaceId),
        ),
      );
      await tester.pumpAndSettle();

      final urlField = find.byKey(
        const ValueKey('home-weblink-capture-url'),
      );
      final submit = find.byKey(
        const ValueKey('home-weblink-capture-submit'),
      );

      await tester.enterText(urlField, 'https://Example.com:443');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('「example.com」を保存しました。'), findsOneWidget);
      final definition = await weblinks.ensureDefinition(workspaceId);
      var objects = await objectStore.listObjects(definition.objectType.id);
      expect(objects, hasLength(1));
      final objectId = objects.single.id;
      expect(
        find.byKey(ValueKey('home-recent-object-$objectId')),
        findsOneWidget,
      );

      await tester.enterText(urlField, 'https://EXAMPLE.COM/');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      objects = await objectStore.listObjects(definition.objectType.id);
      expect(objects, hasLength(1));
      expect(objects.single.id, objectId);
      expect(
        find.byKey(ValueKey('home-recent-object-$objectId')),
        findsOneWidget,
      );

      await tester.enterText(urlField, 'not-a-url');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('有効なURLを入力してください。'), findsOneWidget);
      objects = await objectStore.listObjects(definition.objectType.id);
      expect(objects, hasLength(1));
    },
  );

  testWidgets('Home fails closed on ambiguous canonical Weblink collision', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(store),
    );
    final definition = await weblinks.ensureDefinition(workspaceId);

    for (final url in ['https://example.com/', 'https://EXAMPLE.com:443']) {
      final objectId = await objectStore.createObject(
        objectTypeId: definition.objectType.id,
        title: 'Collision',
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: definition.urlProperty,
        value: url,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: HomeStartPage(store: store, workspaceId: workspaceId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('home-weblink-capture-url')),
      'https://example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey('home-weblink-capture-submit')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('URLを保存できませんでした。入力内容を確認して再試行してください。'),
      findsOneWidget,
    );
    expect(
      await objectStore.listObjects(definition.objectType.id),
      hasLength(2),
    );
  });
}
