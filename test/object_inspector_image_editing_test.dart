import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int attempts = 40,
}) async {
  for (var attempt = 0; attempt < attempts && !condition(); attempt += 1) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

void _closeDatabaseAfterUnmount(WidgetTester tester, AppDatabase database) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await database.close();
  });
}

void main() {
  testWidgets('canonical Image detail edits title and Note only', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    _closeDatabaseAfterUnmount(tester, database);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final image = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/example.png',
      sourceUrl: 'https://cdn.example.com/example.png',
      title: 'Original image',
      originalFilename: 'example.png',
      contentType: 'image/png',
    );

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: image.id,
        ),
      ),
    );
    final titleEditButton = find.byKey(
      const ValueKey('object-title-edit-button'),
    );
    await _pumpUntil(tester, () => titleEditButton.evaluate().isNotEmpty);

    expect(titleEditButton, findsOneWidget);
    expect(
      find.byKey(
        ValueKey('edit-object-value-${definition.noteProperty.id}'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey('edit-object-value-${definition.fileProperty.id}'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        ValueKey('edit-object-value-${definition.sourceUrlProperty.id}'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        ValueKey('edit-object-value-${definition.originalFilenameProperty.id}'),
      ),
      findsNothing,
    );

    await tester.tap(titleEditButton);
    final titleEditField = find.byKey(
      const ValueKey('object-title-edit-field'),
    );
    await _pumpUntil(tester, () => titleEditField.evaluate().isNotEmpty);
    await tester.enterText(titleEditField, 'Edited image');
    await tester.tap(find.byKey(const ValueKey('object-title-edit-save')));
    await _pumpUntil(tester, () => titleEditField.evaluate().isEmpty);

    final noteId = definition.noteProperty.id;
    await tester.tap(find.byKey(ValueKey('edit-object-value-$noteId')));
    final noteEditField = find.byKey(
      ValueKey('object-value-edit-field-$noteId'),
    );
    await _pumpUntil(tester, () => noteEditField.evaluate().isNotEmpty);
    await tester.enterText(noteEditField, 'User note');
    await tester.tap(find.byKey(ValueKey('object-value-edit-save-$noteId')));
    await _pumpUntil(tester, () => noteEditField.evaluate().isEmpty);

    final persisted = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == image.id);
    expect(persisted.title, 'Edited image');
    expect(persisted.values[noteId], 'User note');
    expect(
      persisted.values[definition.fileProperty.id],
      '/managed/example.png',
    );
    expect(
      persisted.values[definition.sourceUrlProperty.id],
      'https://cdn.example.com/example.png',
    );
  });

  testWidgets('legacy-owned Image mirror stays read-only', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    _closeDatabaseAfterUnmount(tester, database);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final image = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: '/managed/legacy.png',
      title: 'Legacy mirror',
      originalFilename: 'legacy.png',
    );
    final legacyPhotoId = await systemObjects.ensureProperty(
      objectTypeId: definition.objectType.id,
      name: 'Legacy Photo ID',
      type: ObjectPropertyType.number,
      config: const {'system': true, 'hidden': true},
    );
    await objectStore.setPropertyValue(
      objectId: image.id,
      property: legacyPhotoId,
      value: 42,
    );

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: image.id,
        ),
      ),
    );
    final imagePanel = find.byKey(
      ValueKey('object-image-detail-panel-${image.id}'),
    );
    await _pumpUntil(tester, () => imagePanel.evaluate().isNotEmpty);

    expect(
      find.byKey(const ValueKey('object-title-edit-button')),
      findsNothing,
    );
    expect(
      find.byKey(
        ValueKey('edit-object-value-${definition.noteProperty.id}'),
      ),
      findsNothing,
    );
  });

  testWidgets('other system Object details remain read-only', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    _closeDatabaseAfterUnmount(tester, database);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await weblinks.ensureDefinition(workspaceId);
    final weblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/article',
      title: 'Example article',
    );

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ObjectInspectorPage(
          store: genericStore,
          objectStore: objectStore,
          objectId: weblink.id,
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => find.text('Example article').evaluate().isNotEmpty,
    );

    expect(
      find.byKey(const ValueKey('object-title-edit-button')),
      findsNothing,
    );
    for (final property in definition.objectType.properties) {
      expect(
        find.byKey(ValueKey('edit-object-value-${property.id}')),
        findsNothing,
      );
    }
  });
}
