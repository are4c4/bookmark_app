import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/features/object/presentation/widgets/object_image_detail_panel.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  testWidgets('Image detail panel refreshes preview after safe edit',
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
    var hostRefreshes = 0;
    final editService = _FakeCanonicalImageEditService();

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
            onChanged: () => hostRefreshes++,
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

    bool rotateRightEnabled() {
      final finder = find.byKey(const ValueKey('object-image-rotate-right'));
      if (finder.evaluate().isEmpty) return false;
      return tester.widget<IconButton>(finder).onPressed != null;
    }

    await pumpUntil(rotateRightEnabled);
    expect(find.text(managedFile.path), findsOneWidget);
    expect(evicted, isEmpty);
    expect(hostRefreshes, 0);

    await tester.tap(find.byKey(const ValueKey('object-image-rotate-right')));
    await pumpUntil(() => evicted.length == 1);
    await pumpUntil(rotateRightEnabled);

    expect(editService.lastWorkspaceId, workspaceId);
    expect(editService.lastObjectId, imageObject.id);
    expect(editService.lastQuarterTurns, 1);
    expect(evicted, [managedFile.path]);
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
