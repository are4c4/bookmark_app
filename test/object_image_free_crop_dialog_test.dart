import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_image_free_crop_dialog.dart';
import 'package:bookmark_app/services/image_visual_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ObjectStore objectStore;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    objectStore = ObjectStore(GenericDatabaseStore(database));
  });

  tearDown(() => database.close());

  testWidgets('free crop is available only with persisted Image geometry',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageFreeCropDialog(
            pathResolver: database.pathResolver,
            objectStore: objectStore,
            objectTypeId: 3,
            objectId: 11,
            visualResolver: ({required objectTypeId, required objectId}) async =>
                const ImageManagedVisual(
              imageObjectId: 11,
              filePath: '/managed/image.png',
              pixelWidth: 400,
              pixelHeight: 200,
            ),
            imageBuilder: (_, __) => const ColoredBox(color: Colors.grey),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('object-image-free-crop-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-image-free-crop-selector')),
      findsOneWidget,
    );
    expect(_applyButton(tester).onPressed, isNotNull);
  });

  testWidgets('free crop can switch to moving and zooming the image',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageFreeCropDialog(
            pathResolver: database.pathResolver,
            objectStore: objectStore,
            objectTypeId: 3,
            objectId: 11,
            visualResolver: ({required objectTypeId, required objectId}) async =>
                const ImageManagedVisual(
              imageObjectId: 11,
              filePath: '/managed/image.png',
              pixelWidth: 400,
              pixelHeight: 200,
            ),
            imageBuilder: (_, __) => const ColoredBox(color: Colors.grey),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('object-image-free-crop-move-image-toggle')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('object-image-free-crop-pan-zoom-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-image-free-crop-selector')),
      findsNothing,
    );
    expect(find.textContaining('ホイールで拡大・縮小'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('object-image-free-crop-move-image-toggle')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('object-image-free-crop-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('object-image-free-crop-pan-zoom-selector')),
      findsNothing,
    );
  });

  testWidgets('missing Image geometry fails closed before free crop',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageFreeCropDialog(
            pathResolver: database.pathResolver,
            objectStore: objectStore,
            objectTypeId: 3,
            objectId: 11,
            visualResolver: ({required objectTypeId, required objectId}) async =>
                const ImageManagedVisual(
              imageObjectId: 11,
              filePath: '/managed/image.png',
            ),
            imageBuilder: (_, __) => const ColoredBox(color: Colors.grey),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('画像サイズを特定できない'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('object-image-free-crop-selector')),
      findsNothing,
    );
    expect(_applyButton(tester).onPressed, isNull);
  });
}

FilledButton _applyButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.byKey(const ValueKey('object-image-free-crop-apply')),
    );
