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
  testWidgets('refresh token re-resolves and evicts same-path preview cache',
      (tester) async {
    final directory = await Directory.systemTemp.createTemp('image_preview_refresh_');
    addTearDown(() => directory.delete(recursive: true));
    final managedFile = File('${directory.path}/managed.png');
    await managedFile.writeAsBytes(const <int>[1, 2, 3]);

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
    final image = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managedFile.path,
      originalFilename: 'managed.png',
      pixelWidth: 640,
      pixelHeight: 480,
    );
    final evicted = <String>[];

    Widget host(int refreshToken) => MaterialApp(
          home: Scaffold(
            body: ObjectImageDetailPreview(
              database: database,
              objectStore: objectStore,
              objectTypeId: definition.objectType.id,
              objectId: image.id,
              refreshToken: refreshToken,
              cacheEvictor: (path) async => evicted.add(path),
              imageBuilder: (_, path) => Text(path),
            ),
          ),
        );

    Future<void> pumpUntil(bool Function() condition) async {
      for (var i = 0; i < 50 && !condition(); i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(condition(), isTrue);
    }

    await tester.pumpWidget(host(0));
    await pumpUntil(() => find.text(managedFile.path).evaluate().isNotEmpty);
    expect(evicted, isEmpty);

    await tester.pumpWidget(host(1));
    await pumpUntil(() => evicted.length == 1);

    expect(evicted, [managedFile.path]);
    expect(find.text(managedFile.path), findsOneWidget);

    // Unmount the stateful preview before DB/filesystem teardown so no pending
    // resolver Future can keep the widget test harness alive.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
