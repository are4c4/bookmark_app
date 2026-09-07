import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_image_detail_panel.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:bookmark_app/services/image_visual_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Image detail panel refreshes preview after safe edit',
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
    var hostRefreshes = 0;
    var resolveCount = 0;
    final editService = _FakeCanonicalImageEditService();

    Future<ImageManagedVisual?> resolveVisual({
      required int objectTypeId,
      required int objectId,
    }) async {
      expect(objectTypeId, 3);
      expect(objectId, visual.imageObjectId);
      resolveCount++;
      return visual;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectImageDetailPanel(
            pathResolver: database.pathResolver,
            objectStore: objectStore,
            workspaceId: 1,
            objectTypeId: 3,
            objectId: visual.imageObjectId,
            editService: editService,
            onChanged: () => hostRefreshes++,
            previewVisualResolver: resolveVisual,
            previewCacheEvictor: (path) async => evicted.add(path),
            previewImageBuilder: (_, path) => Text(path),
          ),
        ),
      ),
    );

    Future<void> pumpUntil(bool Function() condition) async {
      for (var i = 0; i < 30 && !condition(); i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(condition(), isTrue);
    }

    bool rotateRightEnabled() {
      final finder = find.byKey(const ValueKey('object-image-rotate-right'));
      if (finder.evaluate().isEmpty) return false;
      return tester.widget<IconButton>(finder).onPressed != null;
    }

    await pumpUntil(rotateRightEnabled);
    await pumpUntil(() => find.text(visual.filePath).evaluate().isNotEmpty);
    expect(resolveCount, 1);
    expect(evicted, isEmpty);
    expect(hostRefreshes, 0);

    await tester.tap(find.byKey(const ValueKey('object-image-rotate-right')));
    await pumpUntil(() => evicted.length == 1);
    await pumpUntil(rotateRightEnabled);

    expect(editService.lastWorkspaceId, 1);
    expect(editService.lastObjectId, visual.imageObjectId);
    expect(editService.lastQuarterTurns, 1);
    expect(resolveCount, 2);
    expect(evicted, [visual.filePath]);
    expect(hostRefreshes, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _FakeCanonicalImageEditService extends CanonicalImageEditService {
  _FakeCanonicalImageEditService()
      : super(
          resolveStoredFile: ({required workspaceId, required objectId}) async =>
              null,
          resolveExclusiveManagedPath:
              ({required objectId, required filePath}) async => null,
          geometryUpdater: ({
            required workspaceId,
            required objectId,
            required pixelWidth,
            required pixelHeight,
          }) async => _object(objectId),
        );

  int? lastWorkspaceId;
  int? lastObjectId;
  int? lastQuarterTurns;

  @override
  Future<bool> canEdit({required int workspaceId, required int objectId}) async =>
      true;

  @override
  Future<bool> canRestoreOriginal({
    required int workspaceId,
    required int objectId,
  }) async =>
      false;

  @override
  Future<AppObject> edit({
    required int workspaceId,
    required int objectId,
    int quarterTurns = 0,
    bool flipHorizontal = false,
    double? cropAspectRatio,
    Rect? normalizedCropRect,
  }) async {
    lastWorkspaceId = workspaceId;
    lastObjectId = objectId;
    lastQuarterTurns = quarterTurns;
    return _object(objectId);
  }
}

AppObject _object(int id) {
  final now = DateTime(2026, 9, 7);
  return AppObject(
    id: id,
    objectTypeId: 1,
    title: 'Image',
    createdAt: now,
    updatedAt: now,
  );
}
