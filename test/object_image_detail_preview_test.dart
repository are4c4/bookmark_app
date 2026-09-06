import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_image_detail_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Image detail preview resolves managed path and geometry',
      (tester) async {
    final root = await Directory.systemTemp.createTemp('image_detail_preview_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final file = File('${root.path}/photos/preview.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[1]);

    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(store),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final image = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'photos/preview.png',
      title: 'Preview',
      pixelWidth: 800,
      pixelHeight: 400,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageDetailPreview(
            database: database,
            objectStore: objectStore,
            objectTypeId: definition.objectType.id,
            objectId: image.id,
            imageBuilder: (_, path) => Text(
              path,
              key: const ValueKey('resolved-image-path'),
            ),
          ),
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(ValueKey('object-image-preview-${image.id}')),
    );

    expect(find.byKey(const ValueKey('resolved-image-path')), findsOneWidget);
    expect(find.text(file.path), findsOneWidget);
    final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ratio.aspectRatio, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Image detail preview surfaces a missing managed file safely',
      (tester) async {
    final root = await Directory.systemTemp.createTemp('image_detail_missing_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      profileDirectoryPath: root.path,
    );
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final store = GenericDatabaseStore(database);
    final objectStore = ObjectStore(store);
    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(store),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final image = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'photos/missing.png',
      title: 'Missing',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageDetailPreview(
            database: database,
            objectStore: objectStore,
            objectTypeId: definition.objectType.id,
            objectId: image.id,
          ),
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(ValueKey('object-image-preview-missing-${image.id}')),
    );

    expect(find.text('画像ファイルを表示できません'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Expected Image detail preview within 5 seconds.');
}
