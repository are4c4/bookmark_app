import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/core_object_bridge.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_image_relation_service.dart';
import 'package:bookmark_app/widgets/bookmark_image_relation_section.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 40,
}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 25));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets);
}

void main() {
  testWidgets('Bookmark detail selects Image through canonical Relation picker',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await database.close();
    });
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    final lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    final repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
    final bookmarkId = await repository.create(
      url: 'https://bookmark-image-host.example',
      title: 'Image host Bookmark',
      inbox: true,
    );

    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final bridge = CoreObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemStore,
      tagBridge: TagObjectBridge(
        database: database,
        objectStore: objectStore,
        systemObjectStore: systemStore,
      ),
    );
    await bridge.syncAll(workspaceId);

    final image = await ImageObjectService(
      systemObjects: systemStore,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    ).findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'images/host-native.png',
      title: 'Host native image',
      originalFilename: 'host-native.png',
    );
    final bookmark = (await repository.watchAll().first)
        .singleWhere((item) => item.id == bookmarkId);

    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var changeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            child: BookmarkImageRelationSection(
              repository: repository,
              bookmark: bookmark,
              onChanged: () => changeCount += 1,
            ),
          ),
        ),
      ),
    );

    final edit = find.byKey(const ValueKey('bookmark-image-relation-edit'));
    await _pumpUntil(tester, edit);
    expect(
      find.byKey(const ValueKey('bookmark-image-relation-canonical')),
      findsOneWidget,
    );

    await tester.tap(edit);
    await _pumpUntil(tester, find.text('Host native image'));
    await tester.tap(find.text('Host native image'));
    await tester.tap(find.byKey(const ValueKey('object-relation-picker-save')));
    await _pumpUntil(
      tester,
      find.byKey(ValueKey('bookmark-image-relation-card-${image.id}')),
    );

    final state = await BookmarkImageRelationService(database).load(
      workspaceId: workspaceId,
      bookmarkId: bookmarkId,
    );
    expect(state, isNotNull);
    expect(state!.images.selectedObjectIds, <int>[image.id]);
    expect(changeCount, 1);

    final legacyLinkCount = (await database.customSelect(
      'SELECT COUNT(*) AS count FROM bookmark_photos WHERE bookmark_id = ?',
      variables: [Variable<int>(bookmarkId)],
    ).getSingle())
        .read<int>('count');
    expect(legacyLinkCount, 0);
  });
}
