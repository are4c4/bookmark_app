import 'object_body.dart';
import 'object_body_block_contracts.dart';

/// Read-only inventory of first-class references embedded in an Object Body.
///
/// Keeping this domain-only lets future renderers, navigation, cleanup audits,
/// and backlink/index integrations consume the same reference extraction
/// without coupling Body storage to a specific UI.
class ObjectBodyReferenceIndex {
  const ObjectBodyReferenceIndex({
    required this.objectIds,
    required this.databaseIds,
    required this.viewIds,
    required this.assetIds,
  });

  factory ObjectBodyReferenceIndex.fromDocument(ObjectBodyDocument document) {
    final objectIds = <int>{};
    final databaseIds = <int>{};
    final viewIds = <int>{};
    final assetIds = <int>{};

    for (final block in document.blocks) {
      final objectId = block.referencedObjectId;
      if (objectId != null) objectIds.add(objectId);

      final databaseId = block.referencedDatabaseId;
      if (databaseId != null) databaseIds.add(databaseId);

      final viewId = block.referencedViewId;
      if (viewId != null) viewIds.add(viewId);

      final assetId = block.referencedAssetId;
      if (assetId != null) assetIds.add(assetId);
    }

    return ObjectBodyReferenceIndex(
      objectIds: Set<int>.unmodifiable(objectIds),
      databaseIds: Set<int>.unmodifiable(databaseIds),
      viewIds: Set<int>.unmodifiable(viewIds),
      assetIds: Set<int>.unmodifiable(assetIds),
    );
  }

  final Set<int> objectIds;
  final Set<int> databaseIds;
  final Set<int> viewIds;
  final Set<int> assetIds;

  bool get isEmpty =>
      objectIds.isEmpty &&
      databaseIds.isEmpty &&
      viewIds.isEmpty &&
      assetIds.isEmpty;
}
