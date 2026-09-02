import 'object_query.dart';

/// Phase-1 Database membership contract.
///
/// A Database selects Objects from one target ObjectType using a persistent
/// collection-level filter. View filters are intentionally not represented
/// here; they remain a separate presentation/query layer.
class DatabaseCollectionDefinition {
  const DatabaseCollectionDefinition({
    required this.databaseId,
    required this.workspaceId,
    required this.targetObjectTypeId,
    this.collectionFilter = const <ObjectFilterRule>[],
    this.isLegacyFallback = false,
  });

  final int databaseId;
  final int workspaceId;
  final int targetObjectTypeId;
  final List<ObjectFilterRule> collectionFilter;

  /// True when no explicit collection definition has been persisted yet.
  ///
  /// Legacy databases behave as `targetObjectTypeId == databaseId` with an
  /// empty collection filter until the user explicitly changes membership.
  final bool isLegacyFallback;

  DatabaseCollectionDefinition copyWith({
    int? targetObjectTypeId,
    List<ObjectFilterRule>? collectionFilter,
  }) =>
      DatabaseCollectionDefinition(
        databaseId: databaseId,
        workspaceId: workspaceId,
        targetObjectTypeId: targetObjectTypeId ?? this.targetObjectTypeId,
        collectionFilter: List<ObjectFilterRule>.unmodifiable(
          collectionFilter ?? this.collectionFilter,
        ),
      );
}
