import 'package:bookmark_app/domain/object_body_block_contracts.dart';
import 'package:bookmark_app/domain/object_body_reference_insert.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('object reference request creates a fully configured block', () {
    final block = const ObjectBodyObjectReferenceInsert(
      objectId: 42,
      label: ' Related note ',
    ).toBlock(blockId: ' ref-1 ');

    expect(block.id, 'ref-1');
    expect(block.type, ObjectBodyBlockType.objectReference);
    expect(block.text, 'Related note');
    expect(block.referencedObjectId, 42);
  });

  test('database view request preserves optional view identity', () {
    final databaseOnly = const ObjectBodyDatabaseViewInsert(
      databaseId: 3,
    ).toBlock(blockId: 'db-1');
    final specificView = const ObjectBodyDatabaseViewInsert(
      databaseId: 3,
      viewId: 9,
    ).toBlock(blockId: 'db-2');

    expect(databaseOnly.referencedDatabaseId, 3);
    expect(databaseOnly.referencedViewId, isNull);
    expect(specificView.referencedDatabaseId, 3);
    expect(specificView.referencedViewId, 9);
  });

  test('asset request distinguishes image and file without placeholders', () {
    final image = const ObjectBodyAssetReferenceInsert(
      kind: ObjectBodyAssetReferenceKind.image,
      assetId: 11,
      caption: ' Cover ',
    ).toBlock(blockId: 'asset-1');
    final file = const ObjectBodyAssetReferenceInsert(
      kind: ObjectBodyAssetReferenceKind.file,
      assetId: 12,
    ).toBlock(blockId: 'asset-2');

    expect(image.type, ObjectBodyBlockType.image);
    expect(image.referencedAssetId, 11);
    expect(image.attributes[ObjectBodyBlockAttribute.caption], 'Cover');
    expect(file.type, ObjectBodyBlockType.file);
    expect(file.referencedAssetId, 12);
  });

  test('reference requests fail closed for invalid ids', () {
    expect(
      () => const ObjectBodyObjectReferenceInsert(objectId: 0)
          .toBlock(blockId: 'ref'),
      throwsArgumentError,
    );
    expect(
      () => const ObjectBodyDatabaseViewInsert(databaseId: 1, viewId: -1)
          .toBlock(blockId: 'db'),
      throwsArgumentError,
    );
    expect(
      () => const ObjectBodyAssetReferenceInsert(
        kind: ObjectBodyAssetReferenceKind.image,
        assetId: 1,
      ).toBlock(blockId: ' '),
      throwsArgumentError,
    );
  });
}
