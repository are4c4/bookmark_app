import 'dart:io';
import 'dart:ui';

import 'package:image/image.dart' as img;

class ImageEditService {
  const ImageEditService();

  String backupPath(String path) => '$path.bookmark_original';

  bool supports(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png');
  }

  Future<bool> hasBackup(String path) => File(backupPath(path)).exists();

  Future<void> apply({
    required String path,
    int quarterTurns = 0,
    bool flipHorizontal = false,
    double? cropAspectRatio,
    Rect? normalizedCropRect,
  }) async {
    if (!supports(path)) {
      throw StateError('現在の画像編集は JPG / JPEG / PNG に対応しています。');
    }

    final file = File(path);
    if (!await file.exists()) throw StateError('画像ファイルが見つかりません。');

    final backup = File(backupPath(path));
    if (!await backup.exists()) await file.copy(backup.path);

    final bytes = await file.readAsBytes();
    var image = img.decodeImage(bytes);
    if (image == null) throw StateError('画像を読み込めませんでした。');

    final normalizedTurns = ((quarterTurns % 4) + 4) % 4;
    if (normalizedTurns != 0) {
      image = img.copyRotate(image, angle: normalizedTurns * 90);
    }
    if (flipHorizontal) image = img.flipHorizontal(image);

    final freeRect = normalizedCropRect;
    if (freeRect != null) {
      final left = freeRect.left.clamp(0.0, 1.0);
      final top = freeRect.top.clamp(0.0, 1.0);
      final right = freeRect.right.clamp(0.0, 1.0);
      final bottom = freeRect.bottom.clamp(0.0, 1.0);
      final x = (left * image.width).round().clamp(0, image.width - 1);
      final y = (top * image.height).round().clamp(0, image.height - 1);
      final cropWidth = ((right - left) * image.width)
          .round()
          .clamp(1, image.width - x);
      final cropHeight = ((bottom - top) * image.height)
          .round()
          .clamp(1, image.height - y);
      image = img.copyCrop(
        image,
        x: x,
        y: y,
        width: cropWidth,
        height: cropHeight,
      );
    } else if (cropAspectRatio != null && cropAspectRatio > 0) {
      final current = image.width / image.height;
      int cropWidth = image.width;
      int cropHeight = image.height;
      if (current > cropAspectRatio) {
        cropWidth = (image.height * cropAspectRatio).round().clamp(1, image.width);
      } else if (current < cropAspectRatio) {
        cropHeight = (image.width / cropAspectRatio).round().clamp(1, image.height);
      }
      final x = ((image.width - cropWidth) / 2).round();
      final y = ((image.height - cropHeight) / 2).round();
      image = img.copyCrop(image, x: x, y: y, width: cropWidth, height: cropHeight);
    }

    final lower = path.toLowerCase();
    final output = lower.endsWith('.png')
        ? img.encodePng(image)
        : img.encodeJpg(image, quality: 95);
    await file.writeAsBytes(output, flush: true);
  }

  Future<void> restoreOriginal(String path) async {
    final backup = File(backupPath(path));
    if (!await backup.exists()) throw StateError('元画像のバックアップがありません。');
    await backup.copy(path);
  }
}
