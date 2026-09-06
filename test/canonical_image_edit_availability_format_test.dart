import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CanonicalImageEditService serviceForPath(String path) {
    return CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async =>
          'stored/image',
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
          path,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async => AppObject(
        id: objectId,
        objectTypeId: 1,
        title: 'Image',
        createdAt: DateTime(2026, 9, 6),
        updatedAt: DateTime(2026, 9, 6),
      ),
    );
  }

  test('canEdit is true for an exclusively owned supported format', () async {
    expect(
      await serviceForPath('/managed/image.png').canEdit(
        workspaceId: 1,
        objectId: 2,
      ),
      isTrue,
    );
  });

  test('canEdit is false for an exclusively owned unsupported format', () async {
    expect(
      await serviceForPath('/managed/image.gif').canEdit(
        workspaceId: 1,
        objectId: 2,
      ),
      isFalse,
    );
  });
}
