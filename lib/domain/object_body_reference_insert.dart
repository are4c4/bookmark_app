import 'object_body.dart';
import 'object_body_block_contracts.dart';

/// Reference-bearing Body blocks intentionally use an explicit typed request
/// rather than the generic text-block insert menu. This keeps target selection
/// separate from block chrome and prevents creating half-configured references.
sealed class ObjectBodyReferenceInsertRequest {
  const ObjectBodyReferenceInsertRequest();

  ObjectBodyBlock toBlock({
    required String blockId,
    ObjectBodyBlockFactory factory = const ObjectBodyBlockFactory(),
  });
}

class ObjectBodyObjectReferenceInsert extends ObjectBodyReferenceInsertRequest {
  const ObjectBodyObjectReferenceInsert({
    required this.objectId,
    this.label,
  });

  final int objectId;
  final String? label;

  @override
  ObjectBodyBlock toBlock({
    required String blockId,
    ObjectBodyBlockFactory factory = const ObjectBodyBlockFactory(),
  }) =>
      factory.objectReference(
        id: _requireBlockId(blockId),
        objectId: objectId,
        text: _normalizedOptional(label),
      );
}

class ObjectBodyDatabaseViewInsert extends ObjectBodyReferenceInsertRequest {
  const ObjectBodyDatabaseViewInsert({
    required this.databaseId,
    this.viewId,
  });

  final int databaseId;
  final int? viewId;

  @override
  ObjectBodyBlock toBlock({
    required String blockId,
    ObjectBodyBlockFactory factory = const ObjectBodyBlockFactory(),
  }) =>
      factory.databaseView(
        id: _requireBlockId(blockId),
        databaseId: databaseId,
        viewId: viewId,
      );
}

enum ObjectBodyAssetReferenceKind { image, file }

class ObjectBodyAssetReferenceInsert extends ObjectBodyReferenceInsertRequest {
  const ObjectBodyAssetReferenceInsert({
    required this.kind,
    required this.assetId,
    this.caption,
  });

  final ObjectBodyAssetReferenceKind kind;
  final int assetId;
  final String? caption;

  @override
  ObjectBodyBlock toBlock({
    required String blockId,
    ObjectBodyBlockFactory factory = const ObjectBodyBlockFactory(),
  }) =>
      factory.asset(
        id: _requireBlockId(blockId),
        type: switch (kind) {
          ObjectBodyAssetReferenceKind.image => ObjectBodyBlockType.image,
          ObjectBodyAssetReferenceKind.file => ObjectBodyBlockType.file,
        },
        assetId: assetId,
        caption: _normalizedOptional(caption),
      );
}

String _requireBlockId(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'blockId', 'Block id is empty.');
  }
  return normalized;
}

String? _normalizedOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
