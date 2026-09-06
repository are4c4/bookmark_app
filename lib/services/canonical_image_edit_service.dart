import 'dart:io';
import 'dart:ui';

import 'package:image/image.dart' as image;

import '../data/image_object_service.dart';
import '../domain/object_model.dart';
import 'image_edit_service.dart';
import 'image_managed_file_deletion_policy.dart';

typedef ExclusiveManagedImagePathResolver = Future<String?> Function({
  required int objectId,
  required String filePath,
});

typedef CanonicalImageGeometryUpdater = Future<AppObject> Function({
  required int workspaceId,
  required int objectId,
  required int pixelWidth,
  required int pixelHeight,
});

/// Coordinates byte edits for a canonical Image without allowing an editor to
/// mutate a file that may still be shared by another Image or legacy Photo.
///
/// The existing managed-file deletion audit is intentionally reused as the
/// exclusive-ownership proof: a file that could not be removed after deleting
/// this Image also must not be edited in place for this Image. Shared/ambiguous
/// ownership therefore fails closed until an explicit copy-on-edit workflow is
/// introduced.
class CanonicalImageEditService {
  CanonicalImageEditService({
    required this.resolveExclusiveManagedPath,
    required this.geometryUpdater,
    this.imageEdit = const ImageEditService(),
  });

  factory CanonicalImageEditService.fromServices({
    required ImageManagedFileDeletionPolicy ownershipPolicy,
    required ImageObjectService images,
    ImageEditService imageEdit = const ImageEditService(),
  }) {
    return CanonicalImageEditService(
      resolveExclusiveManagedPath: ({required objectId, required filePath}) =>
          ownershipPolicy.deletableManagedPath(
        deletingObjectId: objectId,
        filePath: filePath,
      ),
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) =>
          images.updateManagedGeometry(
        workspaceId: workspaceId,
        objectId: objectId,
        pixelWidth: pixelWidth,
        pixelHeight: pixelHeight,
      ),
      imageEdit: imageEdit,
    );
  }

  final ExclusiveManagedImagePathResolver resolveExclusiveManagedPath;
  final CanonicalImageGeometryUpdater geometryUpdater;
  final ImageEditService imageEdit;

  Future<AppObject> edit({
    required int workspaceId,
    required int objectId,
    required String filePath,
    int quarterTurns = 0,
    bool flipHorizontal = false,
    double? cropAspectRatio,
    Rect? normalizedCropRect,
  }) async {
    final editablePath = await resolveExclusiveManagedPath(
      objectId: objectId,
      filePath: filePath,
    );
    if (editablePath == null) {
      throw const CanonicalImageEditOwnershipException();
    }

    final file = File(editablePath);
    final beforeBytes = await file.readAsBytes();
    final backup = File(imageEdit.backupPath(editablePath));
    final backupExisted = await backup.exists();

    try {
      await imageEdit.apply(
        path: editablePath,
        quarterTurns: quarterTurns,
        flipHorizontal: flipHorizontal,
        cropAspectRatio: cropAspectRatio,
        normalizedCropRect: normalizedCropRect,
      );
      final decoded = image.decodeImage(await file.readAsBytes());
      if (decoded == null) {
        throw StateError('編集後の画像サイズを取得できませんでした。');
      }
      return await geometryUpdater(
        workspaceId: workspaceId,
        objectId: objectId,
        pixelWidth: decoded.width,
        pixelHeight: decoded.height,
      );
    } catch (_) {
      await file.writeAsBytes(beforeBytes, flush: true);
      if (!backupExisted && await backup.exists()) {
        await backup.delete();
      }
      rethrow;
    }
  }
}

class CanonicalImageEditOwnershipException implements Exception {
  const CanonicalImageEditOwnershipException();

  @override
  String toString() =>
      'この画像ファイルは他の画像または従来の写真と共有されている可能性があるため、直接編集できません。';
}
