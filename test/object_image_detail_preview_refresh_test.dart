import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_image_detail_preview.dart';
import 'package:bookmark_app/services/image_visual_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('refresh token re-resolves and evicts same-path preview cache',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    const visual = ImageManagedVisual(
      imageObjectId: 7,
      filePath: '/managed/preview.png',
      pixelWidth: 640,
      pixelHeight: 480,
    );
    final evicted = <String>[];
    var resolveCount = 0;

    Future<ImageManagedVisual?> resolveVisual({
      required int objectTypeId,
      required int objectId,
    }) async {
      expect(objectTypeId, 3);
      expect(objectId, 7);
      resolveCount++;
      return visual;
    }

    Future<void> evictCache(String path) async => evicted.add(path);

    Widget host(int refreshToken) => MaterialApp(
          home: Scaffold(
            body: ObjectImageDetailPreview(
              database: database,
              objectStore: objectStore,
              objectTypeId: 3,
              objectId: 7,
              refreshToken: refreshToken,
              visualResolver: resolveVisual,
              cacheEvictor: evictCache,
              imageBuilder: (_, path) => Text(path),
            ),
          ),
        );

    Future<void> pumpUntil(bool Function() condition) async {
      for (var i = 0; i < 20 && !condition(); i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(condition(), isTrue);
    }

    await tester.pumpWidget(host(0));
    await pumpUntil(() => find.text(visual.filePath).evaluate().isNotEmpty);
    expect(resolveCount, 1);
    expect(evicted, isEmpty);

    await tester.pumpWidget(host(1));
    await pumpUntil(() => evicted.length == 1);
    await pumpUntil(() => find.text(visual.filePath).evaluate().isNotEmpty);

    expect(resolveCount, 2);
    expect(evicted, [visual.filePath]);
    expect(find.text(visual.filePath), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
