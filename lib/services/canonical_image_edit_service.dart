import 'dart:io';
import 'dart:ui';

import 'package:image/image.dart' as image;

import '../data/image_object_service.dart';
import '../domain/object_model.dart';
import 'image_edit_service.dart';
import 'image_managed_file_deletion_policy.dart';

typedef CanonicalImageStoredFileResolver = Future<String?> Function({
  required int workspaceId,
  required int objectId,
});
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
/// The stored File identity is resolved from the canonical Image itself rather
/// than accepted from the presentation caller. The existing managed-file
/// deletion audit is intentionally reused as the exclusive-ownership proof: a
/// file that could not be removed after deleting this Image also must not be
/// edited in place for this Image. Shared/ambiguous ownership therefore fails
/// closed until an explicit copy-on-edit workflow is introduced.
///
/// Both edit and restore keep persisted pixel geometry synchronized. If that
/// metadata update fails after bytes have changed, the pre-operation bytes are
/// restored so the Image Object cannot be left with silently stale geometry.
class CanonicalImageEditService {
  CanonicalImageEditService({
    required this.resolveStoredFile,
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
      resolveStoredFile: ({required workspaceId, required objectId}) async {
        final definition = await images.ensureDefinition(workspaceId);
        final objects = await images.systemObjects.objectStore.listObjects(
          definition.objectType.id,
        );
        for (final object in objects) {
          if (object.id != objectId) continue;
          final stored =
              '${object.values[definition.fileProperty.id] ?? ''}'.trim();
          return stored.isEmpty ? null : stored;
        }
        return null;
      },
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

  final CanonicalImageStoredFileResolver resolveStoredFile;
  final ExclusiveManagedImagePathResolver resolveExclusiveManagedPath;
  final CanonicalImageGeometryUpdater geometryUpdater;
  final ImageEditService imageEdit;

  /// Advisory presentation preflight for whether an in-place canonical Image
  /// edit is currently safe and supported. Edit/restore still repeat ownership
  /// checks immediately before mutation so callers must not treat this as a
  /// durable lock.
  Future<bool> canEdit({
    required int workspaceId,
    required int objectId,
  }) async {
    try {
      final editablePath = await _editablePath(
        workspaceId: workspaceId,
        objectId: objectId,
      );
      return imageEdit.supports(editablePath);
    } on CanonicalImageEditTargetException {
      return false;
    } on CanonicalImageEditOwnershipException {
      return false;
    }
  }

  /// Advisory presentation preflight for whether this canonical Image has an
  /// original backup that can currently be restored safely. Restore support is
  /// intentionally independent of the current file extension: the backup may
  /// exist for a file that is no longer editable by today's format policy.
  Future<bool> canRestoreOriginal({
    required int workspaceId,
    required int objectId,
  }) async {
    try {
      final editablePath = await _editablePath(
        workspaceId: workspaceId,
        objectId: objectId,
      );
      return await imageEdit.hasBackup(editablePath);
    } on CanonicalImageEditTargetException {
      return false;
    } on CanonicalImageEditOwnershipException {
      return false;
    }
  }

  Future<AppObject> edit({
    required int workspaceId,
    required int objectId,
    int quarterTurns = 0,
    bool flipHorizontal = false,
    double? cropAspectRatio,
    Rect? normalizedCropRect,
  }) async {
    _validateCropRequest(
      cropAspectRatio: cropAspectRatio,
      normalizedCropRect: normalizedCropRect,
    );
    final editablePath = await _editablePath(
      workspaceId: workspaceId,
      objectId: objectId,
    );
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
      return await _refreshGeometry(
        workspaceId: workspaceId,
        objectId: objectId,
        file: file,
      );
    } catch (_) {
      await file.writeAsBytes(beforeBytes, flush: true);
      if (!backupExisted && await backup.exists()) {
        await backup.delete();
      }
      rethrow;
    }
  }

  Future<AppObject> restoreOriginal({
    required int workspaceId,
    required int objectId,
  }) async {
    final editablePath = await _editablePath(
      workspaceId: workspaceId,
      objectId: objectId,
    );
    final file = File(editablePath);
    final beforeBytes = await file.readAsBytes();

    try {
      await imageEdit.restoreOriginal(editablePath);
      return await _refreshGeometry(
        workspaceId: workspaceId,
        objectId: objectId,
        file: file,
      );
    } catch (_) {
      await file.writeAsBytes(beforeBytes, flush: true);
      rethrow;
    }
  }

  void _validateCropRequest({
    required double? cropAspectRatio,
    required Rect? normalizedCropRect,
  }) {
    if (cropAspectRatio != null && normalizedCropRect != null) {
      throw ArgumentError('Specify either cropAspectRatio or normalizedCropRect, not both.');
    }
    if (cropAspectRatio != null &&
        (!cropAspectRatio.isFinite || cropAspectRatio <= 0)) {
      throw ArgumentError.value(
        cropAspectRatio,
        'cropAspectRatio',
        'must be finite and greater than zero',
      );
    }
    final rect = normalizedCropRect;
    if (rect == null) return;
    final finite = rect.left.isFinite &&
        rect.top.isFinite &&
        rect.right.isFinite &&
        rect.bottom.isFinite;
    final insideUnitSquare = rect.left >= 0 &&
        rect.top >= 0 &&
        rect.right <= 1 &&
        rect.bottom <= 1;
    if (!finite ||
        !insideUnitSquare ||
        rect.width <= 0 ||
        rect.height <= 0) {
      throw ArgumentError.value(
        rect,
        'normalizedCropRect',
        'must be finite, have positive area, and stay inside the unit square',
      );
    }
  }

  Future<String> _editablePath({
    required int workspaceId,
    required int objectId,
  }) async {
    final storedFile = await resolveStoredFile(
      workspaceId: workspaceId,
      objectId: objectId,
    );
    if (storedFile == null || storedFile.trim().isEmpty) {
      throw const CanonicalImageEditTargetException();
    }
    final editablePath = await resolveExclusiveManagedPath(
      objectId: objectId,
      filePath: storedFile,
    );
    if (editablePath == null) {
      throw const CanonicalImageEditOwnershipException();
    }
    return editablePath;
  }

  Future<AppObject> _refreshGeometry({
    required int workspaceId,
    required int objectId,
    required File file,
  }) async {
    final decoded = image.decodeImage(await file.readAsBytes());
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      throw StateError('編集後の画像サイズを取得できませんでした。');
    }
    return geometryUpdater(
      workspaceId: workspaceId,
      objectId: objectId,
      pixelWidth: decoded.width,
      pixelHeight: decoded.height,
    );
  }
}

class CanonicalImageEditTargetException implements Exception {
  const CanonicalImageEditTargetException();

  @override
  String toString() => '編集対象の画像ファイルを確認できませんでした。';
}

class CanonicalImageEditOwnershipException implements Exception {
  const CanonicalImageEditOwnershipException();

  @override
  String toString() =>
      'この画像ファイルは他の画像または従来の写真と共有されている可能性があるため、直接編集できません。';
}
