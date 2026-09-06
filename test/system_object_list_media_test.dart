import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/features/database/presentation/widgets/system_object_list_media.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      );

  testWidgets('pure content keeps generic fallback for unsupported Objects',
      (tester) async {
    await tester.pumpWidget(
      host(
        const SystemObjectListMediaContent(
          objectId: 7,
          kind: SystemObjectListMediaKind.fallback,
        ),
      ),
    );

    final media = find.byKey(
      const ValueKey('system-object-list-media-fallback-7'),
    );
    expect(media, findsOneWidget);
    expect(tester.getSize(media), const Size.square(44));
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
  });

  testWidgets('supported media falls back to a semantic icon without a file',
      (tester) async {
    await tester.pumpWidget(
      host(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SystemObjectListMediaContent(
              objectId: 8,
              kind: SystemObjectListMediaKind.image,
            ),
            SystemObjectListMediaContent(
              objectId: 9,
              kind: SystemObjectListMediaKind.weblink,
            ),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
  });

  testWidgets('canonical Image List media resolves the managed file read-only',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final temp = await Directory.systemTemp.createTemp('object-list-media-');
    addTearDown(() => temp.delete(recursive: true));
    final managed = File('${temp.path}/example.png');
    await managed.writeAsBytes(const [0]);

    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final imageService = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await imageService.ensureDefinition(workspaceId);
    final image = await imageService.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: managed.path,
      originalFilename: 'example.png',
      pixelWidth: 1200,
      pixelHeight: 800,
    );
    String? resolvedPath;

    await tester.pumpWidget(
      host(
        SystemObjectListMedia(
          database: database,
          objectStore: objectStore,
          workspaceId: workspaceId,
          objectTypeId: definition.objectType.id,
          objectId: image.id,
          imageBuilder: (context, filePath, errorFallback) {
            resolvedPath = filePath;
            return const ColoredBox(color: Colors.black12);
          },
        ),
      ),
    );

    for (var attempt = 0; attempt < 20; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find
          .byKey(ValueKey('system-object-list-media-image-${image.id}'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }

    expect(
      find.byKey(ValueKey('system-object-list-media-image-${image.id}')),
      findsOneWidget,
    );
    expect(resolvedPath, managed.path);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
