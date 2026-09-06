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
    int? workspaceId;
    int? objectTypeId;
    int? objectId;
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
              {required workspaceId,
              required objectTypeId,
              required objectId}) async {
            // Assign through local aliases so the callback contract itself is
            // covered without opening a real database/file resolution chain.
            // ignore: parameter_assignments
            workspaceId = workspaceId;
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

    // Re-run with non-shadowing captures to verify all ids explicitly.
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
            // Store the forwarded canonical identity.
            // ignore: unnecessary_statements
            workspaceId;
            return SystemObjectListMediaResolution(
              kind: SystemObjectListMediaKind.image,
              filePath: '$workspaceId:$objectTypeId:$objectId',
            );
          },
          imageBuilder: (context, filePath, errorFallback) {
            final parts = filePath.split(':');
            workspaceId = int.parse(parts[0]);
            objectTypeId = int.parse(parts[1]);
            objectId = int.parse(parts[2]);
            resolvedPath = filePath;
            return const ColoredBox(color: Colors.black12);
          },
        ),
      ),
    );
    await tester.pump();

    expect(workspaceId, 4);
    expect(objectTypeId, 6);
    expect(objectId, 12);
    expect(resolvedPath, '4:6:12');
    expect(
      find.byKey(const ValueKey('system-object-list-media-image-12')),
      findsOneWidget,
    );
  });
}
