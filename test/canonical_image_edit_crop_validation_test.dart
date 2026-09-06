import 'dart:ui';

import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalid normalized crop fails before target or ownership resolution',
      () async {
    var targetResolved = false;
    var ownershipChecked = false;
    var updated = false;
    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async {
        targetResolved = true;
        return 'managed.png';
      },
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async {
        ownershipChecked = true;
        return filePath;
      },
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async {
        updated = true;
        return _object(objectId);
      },
    );

    await expectLater(
      service.edit(
        workspaceId: 1,
        objectId: 2,
        normalizedCropRect: const Rect.fromLTRB(0.7, 0.1, 0.4, 0.9),
      ),
      throwsArgumentError,
    );

    expect(targetResolved, isFalse);
    expect(ownershipChecked, isFalse);
    expect(updated, isFalse);
  });

  test('crop mode is unambiguous and aspect ratio must be positive', () async {
    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async =>
          'managed.png',
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
          filePath,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async => _object(objectId),
    );

    await expectLater(
      service.edit(
        workspaceId: 1,
        objectId: 2,
        cropAspectRatio: 1,
        normalizedCropRect: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
      ),
      throwsArgumentError,
    );
    await expectLater(
      service.edit(
        workspaceId: 1,
        objectId: 2,
        cropAspectRatio: 0,
      ),
      throwsArgumentError,
    );
  });
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
