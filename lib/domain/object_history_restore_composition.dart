import 'object_history_contract.dart';
import 'object_history_relation.dart';
import 'object_history_restore_planner.dart';

/// A-owned coordination plan that proves the core revision guard and every
/// requested B-owned Relation restore plan agree before any executor mutates
/// canonical state.
///
/// This type grants no Relation mutation authority. Callers must still execute
/// [relationPlans] through the B-owned ObjectHistoryRelationService boundary.
class ObjectHistoryCoordinatedRestorePlan {
  ObjectHistoryCoordinatedRestorePlan({
    required this.corePlan,
    required List<ObjectHistoryRelationRestorePlan> relationPlans,
  }) : relationPlans = List<ObjectHistoryRelationRestorePlan>.unmodifiable(
         relationPlans,
       );

  final ObjectHistoryRestorePlan corePlan;
  final List<ObjectHistoryRelationRestorePlan> relationPlans;

  bool get isExecutable =>
      corePlan.isExecutable && relationPlans.every((plan) => plan.isExecutable);

  List<int> get changedRelationObjectIds {
    final ids = <int>{};
    for (final plan in relationPlans) {
      ids.addAll(plan.changedObjectIds);
    }
    final result = ids.where((id) => id > 0).toList()..sort();
    return List<int>.unmodifiable(result);
  }
}

extension ObjectHistoryRestoreComposition
    on ObjectHistoryCheckpointRestorePreview {
  /// Exact Relation Property ids that must be satisfied by canonical B-owned
  /// restore plans before this preview can become executable.
  ///
  /// The A planner owns the blocker-key format, so callers do not need to parse
  /// implementation strings themselves. Unexpected blocker shapes fail closed.
  List<int> get requiredRelationPropertyIds {
    final ids = <int>{};
    for (final blocker in relationBlockers) {
      const prefix = 'property:';
      if (!blocker.key.startsWith(prefix)) {
        throw StateError(
          'Unsupported Relation history blocker key: ${blocker.key}',
        );
      }
      final raw = blocker.key.substring(prefix.length);
      final propertyId = int.tryParse(raw);
      if (propertyId == null || propertyId <= 0) {
        throw StateError(
          'Invalid Relation history blocker Property id: ${blocker.key}',
        );
      }
      if (!ids.add(propertyId)) {
        throw StateError(
          'Duplicate Relation history blocker for Property $propertyId.',
        );
      }
    }
    final result = ids.toList()..sort();
    return List<int>.unmodifiable(result);
  }

  ObjectHistoryCoordinatedRestorePlan coordinateWithRelations({
    required int actualCurrentRevisionId,
    required List<ObjectHistoryRelationRestorePlan> relationPlans,
  }) {
    if (blockers.isNotEmpty) {
      throw StateError(
        'Cannot coordinate history restore while A-owned blockers remain.',
      );
    }

    final requiredIds = requiredRelationPropertyIds;
    final requiredSet = requiredIds.toSet();
    final byProperty = <int, ObjectHistoryRelationRestorePlan>{};

    for (final relationPlan in relationPlans) {
      final snapshot = relationPlan.historical;
      if (snapshot.sourceObjectId != objectId) {
        throw StateError(
          'Relation history restore plan for Property ${snapshot.propertyId} targets Object ${snapshot.sourceObjectId}, expected Object $objectId.',
        );
      }
      if (!requiredSet.contains(snapshot.propertyId)) {
        throw StateError(
          'Relation history restore plan for unrequested Property ${snapshot.propertyId} was supplied.',
        );
      }
      if (byProperty.putIfAbsent(snapshot.propertyId, () => relationPlan) !=
          relationPlan) {
        throw StateError(
          'Multiple Relation history restore plans were supplied for Property ${snapshot.propertyId}.',
        );
      }
      if (!relationPlan.isExecutable) {
        throw StateError(
          'Relation history restore plan for Property ${snapshot.propertyId} is blocked.',
        );
      }
    }

    final missing = requiredIds
        .where((propertyId) => !byProperty.containsKey(propertyId))
        .toList();
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing canonical Relation history restore plans for Properties: ${missing.join(', ')}.',
      );
    }

    final corePlan = ObjectHistoryRestorePlan(
      objectId: objectId,
      historicalRevisionId: historicalRevisionId,
      expectedCurrentRevisionId: preparedCurrentRevisionId,
      actualCurrentRevisionId: actualCurrentRevisionId,
      scope: scope,
    );
    if (!corePlan.isExecutable) {
      throw StateError(
        'History restore current revision changed after preview; prepare again.',
      );
    }

    return ObjectHistoryCoordinatedRestorePlan(
      corePlan: corePlan,
      relationPlans: <ObjectHistoryRelationRestorePlan>[
        for (final propertyId in requiredIds) byProperty[propertyId]!,
      ],
    );
  }
}
