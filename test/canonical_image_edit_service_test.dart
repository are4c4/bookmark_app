import 'dart:io';

import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:bookmark_app/services/image_edit_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  AppObject expectedObject({int id = 7}) {
    final now = DateTime(2026, 9, 6);
    return AppObject(
      id: id,
      objectTypeId: 3,
      title: 'Image',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('exclusive canonical Image edit refreshes persisted geometry', () async {
    final directory = await Directory.systemTemp.createTemp('canonical_edit_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.png');
    await file.writeAsBytes(image.encodePng(image.Image(width: 4, height: 2)));

    int? updatedWidth;
    int? updatedHeight;
    final expected = expectedObject();
    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async {
        expect(workspaceId, 11);
        expect(objectId, 7);
        return 'stored/image.png';
      },
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async {
        expect(objectId, 7);
        expect(filePath, 'stored/image.png');
        return file.path;
      },
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async {
        expect(workspaceId, 11);
        expect(objectId, 7);
        updatedWidth = pixelWidth;
        updatedHeight = pixelHeight;
        return expected;
      },
    );

    final result = await service.edit(
      workspaceId: 11,
      objectId: 7,
      quarterTurns: 1,
    );

    final decoded = image.decodeImage(await file.readAsBytes());
    expect(result, same(expected));
    expect(decoded, isNotNull);
    expect(decoded!.width, 2);
    expect(decoded.height, 4);
    expect(updatedWidth, 2);
    expect(updatedHeight, 4);
  });

  test('missing canonical Image file fails before ownership audit', () async {
    var ownershipChecked = false;
    var updated = false;
    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async => null,
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
        return expectedObject(id: objectId);
      },
    );

    await expectLater(
      service.edit(workspaceId: 1, objectId: 2, quarterTurns: 1),
      throwsA(isA<CanonicalImageEditTargetException>()),
    );
    expect(ownershipChecked, isFalse);
    expect(updated, isFalse);
  });

  test('shared or ambiguous managed Image fails closed before mutation', () async {
    var updated = false;
    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async =>
          'shared.png',
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
          null,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async {
        updated = true;
        return expectedObject(id: objectId);
      },
    );

    await expectLater(
      service.edit(workspaceId: 1, objectId: 2, quarterTurns: 1),
      throwsA(isA<CanonicalImageEditOwnershipException>()),
    );
    expect(updated, isFalse);
  });

  test('geometry persistence failure rolls back edited bytes and new backup', () async {
    final directory = await Directory.systemTemp.createTemp('canonical_edit_rollback_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.png');
    final original = image.encodePng(image.Image(width: 5, height: 3));
    await file.writeAsBytes(original);

    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async =>
          'stored/image.png',
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
          file.path,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async => throw StateError('persist failed'),
    );

    await expectLater(
      service.edit(workspaceId: 1, objectId: 2, quarterTurns: 1),
      throwsStateError,
    );

    expect(await file.readAsBytes(), original);
    expect(await File('${file.path}.bookmark_original').exists(), isFalse);
  });

  test('canonical restore uses the same ownership guard and refreshes geometry',
      () async {
    final directory = await Directory.systemTemp.createTemp('canonical_restore_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.png');
    await file.writeAsBytes(image.encodePng(image.Image(width: 6, height: 4)));
    const rawEdit = ImageEditService();
    await rawEdit.apply(path: file.path, quarterTurns: 1);
    final edited = image.decodeImage(await file.readAsBytes());
    expect(edited, isNotNull);
    expect(edited!.width, 4);
    expect(edited.height, 6);

    int? updatedWidth;
    int? updatedHeight;
    final expected = expectedObject(id: 9);
    final service = CanonicalImageEditService(
      resolveStoredFile: ({required workspaceId, required objectId}) async =>
          'stored/image.png',
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async =>
          file.path,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async {
        updatedWidth = pixelWidth;
        updatedHeight = pixelHeight;
        return expected;
      },
    );

    final result = await service.restoreOriginal(workspaceId: 1, objectId: 9);

    final restored = image.decodeImage(await file.readAsBytes());
    expect(result, same(expected));
    expect(restored, isNotNull);
    expect(restored!.width, 6);
    expect(restored.height, 4);
    expect(updatedWidth, 6);
    expect(updatedHeight, 4);
  });
}
