import 'dart:io';

import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/services/canonical_image_edit_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('exclusive managed Image edit refreshes persisted geometry', () async {
    final directory = await Directory.systemTemp.createTemp('canonical_edit_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/image.png');
    await file.writeAsBytes(image.encodePng(image.Image(width: 4, height: 2)));

    int? updatedWidth;
    int? updatedHeight;
    final now = DateTime(2026, 9, 6);
    final expected = AppObject(
      id: 7,
      objectTypeId: 3,
      title: 'Image',
      createdAt: now,
      updatedAt: now,
    );
    final service = CanonicalImageEditService(
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
      filePath: 'stored/image.png',
      quarterTurns: 1,
    );

    expect(result, same(expected));
    expect(updatedWidth, 2);
    expect(updatedHeight, 4);
  });

  test('shared or ambiguous managed Image fails closed before mutation', () async {
    var updated = false;
    final service = CanonicalImageEditService(
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async => null,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async {
        updated = true;
        throw StateError('must not update');
      },
    );

    await expectLater(
      service.edit(
        workspaceId: 1,
        objectId: 2,
        filePath: 'shared.png',
        quarterTurns: 1,
      ),
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
      resolveExclusiveManagedPath: ({required objectId, required filePath}) async => file.path,
      geometryUpdater: ({
        required workspaceId,
        required objectId,
        required pixelWidth,
        required pixelHeight,
      }) async => throw StateError('persist failed'),
    );

    await expectLater(
      service.edit(
        workspaceId: 1,
        objectId: 2,
        filePath: file.path,
        quarterTurns: 1,
      ),
      throwsStateError,
    );

    expect(await file.readAsBytes(), original);
    expect(await File('${file.path}.bookmark_original').exists(), isFalse);
  });
}
