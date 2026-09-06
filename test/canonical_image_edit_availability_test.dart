import 'package:flutter_test/flutter_test.dart';

import 'package:bookmark_app/services/canonical_image_edit_service.dart';

void main() {
  group('CanonicalImageEditService.canEdit', () {
    test('is true when the canonical file is exclusively managed', () async {
      final service = CanonicalImageEditService(
        resolveStoredFile: ({required workspaceId, required objectId}) async =>
            'photos/image.jpg',
        resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
            '/profile/photos/image.jpg',
        geometryUpdater: ({
          required workspaceId,
          required objectId,
          required pixelWidth,
          required pixelHeight,
        }) =>
            throw UnimplementedError(),
      );

      expect(
        await service.canEdit(workspaceId: 1, objectId: 42),
        isTrue,
      );
    });

    test('is false when the canonical Image has no stored File', () async {
      var ownershipChecked = false;
      final service = CanonicalImageEditService(
        resolveStoredFile: ({required workspaceId, required objectId}) async =>
            null,
        resolveExclusiveManagedPath: ({required objectId, required filePath}) async {
          ownershipChecked = true;
          return '/profile/photos/image.jpg';
        },
        geometryUpdater: ({
          required workspaceId,
          required objectId,
          required pixelWidth,
          required pixelHeight,
        }) =>
            throw UnimplementedError(),
      );

      expect(
        await service.canEdit(workspaceId: 1, objectId: 42),
        isFalse,
      );
      expect(ownershipChecked, isFalse);
    });

    test('is false when managed-file ownership is shared or ambiguous', () async {
      final service = CanonicalImageEditService(
        resolveStoredFile: ({required workspaceId, required objectId}) async =>
            'photos/image.jpg',
        resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
            null,
        geometryUpdater: ({
          required workspaceId,
          required objectId,
          required pixelWidth,
          required pixelHeight,
        }) =>
            throw UnimplementedError(),
      );

      expect(
        await service.canEdit(workspaceId: 1, objectId: 42),
        isFalse,
      );
    });
  });
}
