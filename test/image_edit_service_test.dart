import 'dart:io';
import 'dart:ui';

import 'package:bookmark_app/services/image_edit_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const service = ImageEditService();
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('bookmark_crop_test_');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<File> createImage({int width = 100, int height = 80}) async {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgba(x, y, x, y, 100, 255);
      }
    }
    final file = File('${tempDirectory.path}/source.png');
    await file.writeAsBytes(img.encodePng(image));
    return file;
  }

  test('free crop uses normalized rectangle coordinates', () async {
    final file = await createImage();

    await service.apply(
      path: file.path,
      normalizedCropRect: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
    );

    final result = img.decodeImage(await file.readAsBytes());
    expect(result, isNotNull);
    expect(result!.width, 50);
    expect(result.height, 40);
  });

  test('free crop is applied after rotation', () async {
    final file = await createImage(width: 120, height: 80);

    await service.apply(
      path: file.path,
      quarterTurns: 1,
      normalizedCropRect: const Rect.fromLTWH(0, 0, 0.5, 1),
    );

    final result = img.decodeImage(await file.readAsBytes());
    expect(result, isNotNull);
    expect(result!.width, 40);
    expect(result.height, 120);
  });

  test('first edit preserves a restorable original backup', () async {
    final file = await createImage(width: 90, height: 60);

    await service.apply(
      path: file.path,
      normalizedCropRect: const Rect.fromLTWH(0, 0, 0.5, 1),
    );
    expect(await service.hasBackup(file.path), isTrue);

    await service.restoreOriginal(file.path);
    final restored = img.decodeImage(await file.readAsBytes());
    expect(restored, isNotNull);
    expect(restored!.width, 90);
    expect(restored.height, 60);
  });
}
