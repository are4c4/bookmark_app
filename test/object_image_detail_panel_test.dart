import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_image_detail_panel.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  testWidgets('Image detail panel refreshes preview after safe same-path edit',
      (tester) async {
    final directory = await Directory.systemTemp.createTemp('image_detail_panel_');
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/managed.png');
    await managedFile.writeAsBytes(
      image.encodePng(image.Image(width: 4, height: 2)),
    );

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final imageObject = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedFile.path,
      originalFilename: 'managed.png',
      pixelWidth: 4,
      pixelHeight: 2,
    );
    final evicted = <String>[];
    final editService = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async {
        expect(workspaceId, greaterThan(0));
        expect(objectId, imageObject.id);
        return managedFile.path;
      },
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async {
        expect(objectId, imageObject.id);
        expect(filePath, managedFile.path);
        return managedFile.path;
      },
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) =>
          images.updateManagedGeometry(
        workspaceId: workspaceId,
        objectId: objectId,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageDetailPanel(
            database: database,
            objectStore: objectStore,
            workspaceId: workspaceId,
            objectTypeId: definition.objectType.id,
            objectId: imageObject.id,
            editService: editService,
            previewCacheEvictor: (path) async => evicted.add(path),
            previewImageBuilder: (_, path) => Text(path),
          ),
        ),
      ),
    );

    Future<void> pumpUntil(bool Function() condition) async {
      for (var i = 0; i < 60 && !condition(); i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(condition(), isTrue);
    }

    await pumpUntil(() {
      final finder = find.byKey(const ValueKey('object-image-rotate-right'));
      if (finder.evaluate().isEmpty) return false;
      return tester.widget<IconButton>(finder).onPressed != null;
    });
    expect(find.text(managedFile.path), findsOneWidget);
    expect(evicted, isEmpty);

    await tester.tap(find.byKey(const ValueKey('object-image-rotate-right')));
    await pumpUntil(() => evicted.length == 1);

    expect(evicted, [managedFile.path]);
    final persisted = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == imageObject.id);
    expect(persisted.values[definition.pixelWidthProperty.id], 2);
    expect(persisted.values[definition.pixelHeightProperty.id], 4);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
