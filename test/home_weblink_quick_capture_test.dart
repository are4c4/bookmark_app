import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/canonical_weblink_capture_service.dart';
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
  testWidgets('Enter capture creates one canonical Weblink and refreshes Recent', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeStartPage(store: store, workspaceId: workspaceId),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('home-weblink-url-field'));
    await tester.tap(field);
    await tester.enterText(field, 'HTTPS://EXAMPLE.COM:443');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Weblinkを保存しました。'), findsOneWidget);
    final weblinks = _weblinks(store, objectStore);
    final definition = await weblinks.ensureDefinition(workspaceId);
    final objects = await objectStore.listObjects(definition.objectType.id);
    expect(objects, hasLength(1));
    expect(objects.single.values[definition.urlProperty.id], 'https://example.com/');
    expect(
      find.byKey(ValueKey('home-recent-object-${objects.single.id}')),
      findsOneWidget,
    );

    await tester.enterText(field, 'not a url');
    await tester.tap(find.byKey(const ValueKey('home-weblink-capture-button')));
    await tester.pumpAndSettle();

    expect(find.text('有効なURLを入力してください。'), findsOneWidget);
    expect(
      await objectStore.listObjects(definition.objectType.id),
      hasLength(1),
    );
  });

  testWidgets(
    'pointer reuse keeps canonical updatedAt and exposes exact Object through success action',
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
      final capture = CanonicalWeblinkCaptureService(weblinks: weblinks);
      final existing = await capture.capture(
        workspaceId: workspaceId,
        url: 'https://example.com/path',
      );
      final definition = await weblinks.ensureDefinition(workspaceId);
      final before = (await objectStore.listObjects(definition.objectType.id))
          .singleWhere((object) => object.id == existing.id);

      final notesTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Notes',
        icon: '📝',
      );
      await objectStore.createObject(
        objectTypeId: notesTypeId,
        title: 'Newer item',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeStartPage(
            store: store,
            workspaceId: workspaceId,
            recentLimit: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Newer item'), findsOneWidget);
      expect(
        find.byKey(ValueKey('home-recent-object-${existing.id}')),
        findsNothing,
      );

      final field = find.byKey(const ValueKey('home-weblink-url-field'));
      await tester.enterText(field, 'HTTPS://EXAMPLE.COM:443/path');
      await tester.tap(find.byKey(const ValueKey('home-weblink-capture-button')));
      await tester.pumpAndSettle();

      final afterObjects = await objectStore.listObjects(definition.objectType.id);
      expect(afterObjects, hasLength(1));
      final after = afterObjects.single;
      expect(after.id, existing.id);
      expect(after.updatedAt, before.updatedAt);
      expect(find.text('Newer item'), findsOneWidget);
      expect(
        find.byKey(ValueKey('home-recent-object-${existing.id}')),
        findsNothing,
      );
      expect(find.text('Weblinkを保存しました。'), findsOneWidget);
      expect(find.text('開く'), findsOneWidget);

      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      expect(find.text('example.com'), findsWidgets);
    },
  );

  testWidgets('ambiguous canonical collision fails closed without another Object', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final weblinks = _weblinks(store, objectStore);
    final definition = await weblinks.ensureDefinition(workspaceId);

    for (final title in <String>['Duplicate A', 'Duplicate B']) {
      final objectId = await objectStore.createObject(
        objectTypeId: definition.objectType.id,
        title: title,
      );
      await objectStore.setPropertyValue(
        objectId: objectId,
        property: definition.urlProperty,
        value: 'https://example.com/',
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: HomeStartPage(store: store, workspaceId: workspaceId),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('home-weblink-url-field'));
    await tester.enterText(field, 'https://example.com');
    await tester.tap(find.byKey(const ValueKey('home-weblink-capture-button')));
    await tester.pumpAndSettle();

    expect(find.text('Weblinkを保存できませんでした。'), findsOneWidget);
    expect(
      await objectStore.listObjects(definition.objectType.id),
      hasLength(2),
    );
  });
}

WeblinkObjectService _weblinks(
  GenericDatabaseStore store,
  ObjectStore objectStore,
) {
  return WeblinkObjectService(
    systemObjects: SystemObjectStore(
      database: store.database,
      objectStore: objectStore,
    ),
    defaultsStore: ObjectTypeDefaultsStore(store),
  );
}
