import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_image_detail_section.dart';
import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  testWidgets('safe edit refreshes same-path preview and persisted geometry',
      (tester) async {
    final directory = await Directory.systemTemp.createTemp('image_detail_section_');
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/managed.png');
    await managedFile.writeAsBytes(
      image.encodePng(image.Image(width: 4, height: 2)),
    );

    final database = AppDatabase.forTesting(NativeDatabase.memory());
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
    final managedImage = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedFile.path,
      originalFilename: 'managed.png',
      pixelWidth: 4,
      pixelHeight: 2,
    );

    final evicted = <String>[];
    var changed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageDetailSection.fromStores(
            store: store,
            objectStore: objectStore,
            workspaceId: workspaceId,
            objectTypeId: definition.objectType.id,
            objectId: managedImage.id,
            photoStorage: PhotoStorageService(
              photoDirectoryPath: directory.path,
            ),
            onChanged: () => changed++,
            previewCacheEvictor: (path) async => evicted.add(path),
            previewImageBuilder: (_, path) => Text(path),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('object-image-detail-section-${managedImage.id}')),
      findsOneWidget,
    );
    expect(find.text(managedFile.path), findsOneWidget);
    expect(evicted, isEmpty);

    await tester.tap(find.byKey(const ValueKey('object-image-rotate-right')));
    await tester.pumpAndSettle();

    expect(changed, 1);
    expect(evicted, [managedFile.path]);
    final edited = image.decodeImage(await managedFile.readAsBytes());
    expect(edited, isNotNull);
    expect(edited!.width, 2);
    expect(edited.height, 4);

    final persisted = (await objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == managedImage.id);
    expect(persisted.values[definition.pixelWidthProperty.id], 2);
    expect(persisted.values[definition.pixelHeightProperty.id], 4);
    expect(
      find.byKey(const ValueKey('object-image-restore-original')),
      findsOneWidget,
    );
  });
}
