import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
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

  testWidgets('List media resolver seam forwards canonical identity and file',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    int? capturedWorkspaceId;
    int? capturedObjectTypeId;
    int? capturedObjectId;
    String? resolvedPath;

    await tester.pumpWidget(
      host(
        SystemObjectListMedia(
          database: database,
          objectStore: objectStore,
          workspaceId: 4,
          objectTypeId: 6,
          objectId: 12,
          visualResolver: (
              {required int workspaceId,
              required int objectTypeId,
              required int objectId}) async {
            capturedWorkspaceId = workspaceId;
            capturedObjectTypeId = objectTypeId;
            capturedObjectId = objectId;
            return const SystemObjectListMediaResolution(
              kind: SystemObjectListMediaKind.image,
              filePath: '/managed/example.png',
            );
          },
          imageBuilder: (context, filePath, errorFallback) {
            resolvedPath = filePath;
            return const ColoredBox(color: Colors.black12);
          },
        ),
      ),
    );
    await tester.pump();

    expect(capturedWorkspaceId, 4);
    expect(capturedObjectTypeId, 6);
    expect(capturedObjectId, 12);
    expect(resolvedPath, '/managed/example.png');
    expect(
      find.byKey(const ValueKey('system-object-list-media-image-12')),
      findsOneWidget,
    );
  });
}
