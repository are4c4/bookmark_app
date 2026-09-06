import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_weblink_detail_preview.dart';
import 'package:bookmark_app/services/weblink_visual_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Weblink detail preview uses managed path and geometry',
      (tester) async {
    const visual = WeblinkManagedVisual(
      imageObjectId: 21,
      filePath: '/resolved/profile/photos/weblink.png',
      pixelWidth: 1200,
      pixelHeight: 600,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectWeblinkDetailPreviewContent(
            objectId: 7,
            isLoading: false,
            visual: visual,
            imageBuilder: (_, path) => Text(
              path,
              key: const ValueKey('resolved-weblink-image-path'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('object-weblink-preview-7')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('resolved-weblink-image-path')),
      findsOneWidget,
    );
    expect(find.text(visual.filePath), findsOneWidget);
    final ratio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ratio.aspectRatio, 2);
  });

  testWidgets('Weblink without representative Image collapses cleanly',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectWeblinkDetailPreviewContent(
            objectId: 8,
            isLoading: false,
            visual: null,
          ),
        ),
      ),
    );

    final missing = find.byKey(
      const ValueKey('object-weblink-preview-missing-8'),
    );
    expect(missing, findsOneWidget);
    expect(tester.getSize(missing), Size.zero);
  });

  testWidgets('Weblink detail preview exposes bounded loading state',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectWeblinkDetailPreviewContent(
            objectId: 9,
            isLoading: true,
            visual: null,
          ),
        ),
      ),
    );

    final loading = find.byKey(
      const ValueKey('object-weblink-preview-loading-9'),
    );
    expect(loading, findsOneWidget);
    expect(tester.getSize(loading).height, 120);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Weblink preview resolver seam receives canonical identity',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    int? resolvedTypeId;
    int? resolvedObjectId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectWeblinkDetailPreview(
            database: database,
            objectStore: objectStore,
            objectTypeId: 3,
            objectId: 14,
            visualResolver: ({required objectTypeId, required objectId}) async {
              resolvedTypeId = objectTypeId;
              resolvedObjectId = objectId;
              return const WeblinkManagedVisual(
                imageObjectId: 22,
                filePath: '/managed/representative.png',
                pixelWidth: 400,
                pixelHeight: 200,
              );
            },
            imageBuilder: (_, __) => const ColoredBox(color: Colors.black12),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(resolvedTypeId, 3);
    expect(resolvedObjectId, 14);
    expect(
      find.byKey(const ValueKey('object-weblink-preview-14')),
      findsOneWidget,
    );
  });
}
