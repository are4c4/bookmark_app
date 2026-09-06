import 'dart:io';

import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:bookmark_app/services/image_edit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppObject object(int id) {
    final now = DateTime(2026, 9, 6);
    return AppObject(
      id: id,
      objectTypeId: 1,
      title: 'Image',
      createdAt: now,
      updatedAt: now,
    );
  }

  CanonicalImageEditService serviceFor({
    required String? storedFile,
    required String? managedPath,
  }) {
    return CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async =>
          storedFile,
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
          managedPath,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async =>
          object(objectId),
    );
  }

  test('canRestoreOriginal is true only when an owned backup exists', () async {
    final directory =
        await Directory.systemTemp.createTemp('canonical_restore_preflight_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.gif');
    await file.writeAsBytes(<int>[1, 2, 3]);

    final service = serviceFor(
      storedFile: 'stored/image.gif',
      managedPath: file.path,
    );

    expect(
      await service.canRestoreOriginal(workspaceId: 1, objectId: 2),
      isFalse,
    );

    final backup = File(const ImageEditService().backupPath(file.path));
    await backup.writeAsBytes(<int>[9, 8, 7]);

    expect(
      await service.canRestoreOriginal(workspaceId: 1, objectId: 2),
      isTrue,
    );
  });

  test('canRestoreOriginal fails closed for missing or shared target', () async {
    final missing = serviceFor(storedFile: null, managedPath: '/unused');
    expect(
      await missing.canRestoreOriginal(workspaceId: 1, objectId: 2),
      isFalse,
    );

    final shared = serviceFor(storedFile: 'stored/image.png', managedPath: null);
    expect(
      await shared.canRestoreOriginal(workspaceId: 1, objectId: 2),
      isFalse,
    );
  });
}
