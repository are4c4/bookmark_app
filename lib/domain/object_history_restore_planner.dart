import 'object_history_checkpoint.dart';
import 'object_history_contract.dart';

/// Whether one A-owned field is already equal to the historical checkpoint or
/// would need an explicit restore mutation later.
enum ObjectHistoryRestoreDecisionKind { noChange, restore }

class ObjectHistoryRestoreFieldDecision {
  const ObjectHistoryRestoreFieldDecision({
    required this.target,
    required this.kind,
  });

  final ObjectHistoryFieldTarget target;
  final ObjectHistoryRestoreDecisionKind kind;

  bool get needsRestore => kind == ObjectHistoryRestoreDecisionKind.restore;
}

/// A fail-closed A-owned reason why a requested historical field cannot yet be
/// prepared for restore.
class ObjectHistoryRestoreBlocker {
  ObjectHistoryRestoreBlocker({required this.key, required this.reason}) {
    if (key.isEmpty || key.trim() != key) {
      throw ArgumentError.value(
        key,
        'key',
        'History restore blocker keys must be non-empty and normalized.',
      );
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'History restore blockers require a non-empty explanation.',
      );
    }
  }

  final String key;
  final String reason;
}

/// Pure preview connecting an immutable checkpoint payload to the established
/// revision/scope restore contract.
///
/// This preview grants no mutation authority. A-owned blockers must be resolved
/// before an execution plan can even be prepared. Relation blockers are carried
/// into [ObjectHistoryRestorePlan] so B-owned integrity remains mandatory.
class ObjectHistoryCheckpointRestorePreview {
  ObjectHistoryCheckpointRestorePreview({
    required this.objectId,
    required this.historicalRevisionId,
    required this.preparedCurrentRevisionId,
    required this.scope,
    required List<ObjectHistoryRestoreFieldDecision> decisions,
    List<ObjectHistoryRestoreBlocker> blockers =
        const <ObjectHistoryRestoreBlocker>[],
    List<ObjectHistoryRelationBlocker> relationBlockers =
        const <ObjectHistoryRelationBlocker>[],
  }) : decisions = List<ObjectHistoryRestoreFieldDecision>.unmodifiable(
         decisions,
       ),
       blockers = List<ObjectHistoryRestoreBlocker>.unmodifiable(blockers),
       relationBlockers = List<ObjectHistoryRelationBlocker>.unmodifiable(
         relationBlockers,
       );

  final int objectId;
  final int historicalRevisionId;
  final int preparedCurrentRevisionId;
  final ObjectHistoryRestoreScope scope;
  final List<ObjectHistoryRestoreFieldDecision> decisions;
  final List<ObjectHistoryRestoreBlocker> blockers;
  final List<ObjectHistoryRelationBlocker> relationBlockers;

  bool get hasAOwnedBlockers => blockers.isNotEmpty;
  bool get hasChanges => decisions.any((decision) => decision.needsRestore);

  /// Builds the already-established execution-time revision guard only after
  /// all A-owned payload blockers have been resolved.
  ///
  /// Relation blockers intentionally remain in the returned plan, making it
  /// non-executable until the B-owned restore contract has validated them.
  ObjectHistoryRestorePlan planForExecution({
    required int actualCurrentRevisionId,
  }) {
    if (blockers.isNotEmpty) {
      throw StateError(
        'Cannot prepare history restore execution while A-owned blockers remain.',
      );
    }
    return ObjectHistoryRestorePlan(
      objectId: objectId,
      historicalRevisionId: historicalRevisionId,
      expectedCurrentRevisionId: preparedCurrentRevisionId,
      actualCurrentRevisionId: actualCurrentRevisionId,
      scope: scope,
      relationBlockers: relationBlockers,
    );
  }
}

class ObjectHistoryCheckpointRestorePlanner {
  const ObjectHistoryCheckpointRestorePlanner();

  ObjectHistoryCheckpointRestorePreview preview({
    required ObjectHistoryCheckpointPayload historical,
    required ObjectHistoryCheckpointPayload current,
    required ObjectHistoryRestoreScope scope,
  }) {
    if (historical.entry.objectId != current.entry.objectId) {
      throw ArgumentError(
        'History restore checkpoints must belong to the same Object.',
      );
    }
    if (historical.entry.revisionId >= current.entry.revisionId) {
      throw ArgumentError(
        'History restore must target a checkpoint older than the current revision.',
      );
    }

    final decisions = <ObjectHistoryRestoreFieldDecision>[];
    final blockers = <ObjectHistoryRestoreBlocker>[];
    final relationBlockers = <ObjectHistoryRelationBlocker>[];
    final historicalValues = <int, ObjectHistoryPropertySnapshot>{
      for (final snapshot in historical.propertySnapshots)
        snapshot.propertyId: snapshot,
    };
    final currentValues = <int, ObjectHistoryPropertySnapshot>{
      for (final snapshot in current.propertySnapshots)
        snapshot.propertyId: snapshot,
    };
    final historicalRelations = <int>{
      for (final requirement in historical.relationRequirements)
        requirement.propertyId,
    };
    final currentRelations = <int>{
      for (final requirement in current.relationRequirements)
        requirement.propertyId,
    };

    void addTitleDecision() {
      decisions.add(
        ObjectHistoryRestoreFieldDecision(
          target: ObjectHistoryFieldTarget.title(),
          kind: historical.title == current.title
              ? ObjectHistoryRestoreDecisionKind.noChange
              : ObjectHistoryRestoreDecisionKind.restore,
        ),
      );
    }

    void addBodyDecision() {
      decisions.add(
        ObjectHistoryRestoreFieldDecision(
          target: ObjectHistoryFieldTarget.body(),
          kind: _jsonEquals(historical.body.toJson(), current.body.toJson())
              ? ObjectHistoryRestoreDecisionKind.noChange
              : ObjectHistoryRestoreDecisionKind.restore,
        ),
      );
    }

    void addPropertyDecision(int propertyId) {
      if (historicalRelations.contains(propertyId) ||
          currentRelations.contains(propertyId)) {
        relationBlockers.add(
          ObjectHistoryRelationBlocker(
            key: 'property:$propertyId',
            reason:
                'Relation Property $propertyId requires canonical B-owned history restore validation.',
          ),
        );
        return;
      }

      final historicalSnapshot = historicalValues[propertyId];
      final currentSnapshot = currentValues[propertyId];
      if (historicalSnapshot == null || currentSnapshot == null) {
        blockers.add(
          ObjectHistoryRestoreBlocker(
            key: 'property:$propertyId',
            reason:
                'Value Property $propertyId is not represented in both the historical and current checkpoint payloads.',
          ),
        );
        return;
      }
      if (historicalSnapshot.type != currentSnapshot.type) {
        blockers.add(
          ObjectHistoryRestoreBlocker(
            key: 'property:$propertyId',
            reason:
                'Value Property $propertyId changed type between the historical and current checkpoint payloads.',
          ),
        );
        return;
      }

      decisions.add(
        ObjectHistoryRestoreFieldDecision(
          target: ObjectHistoryFieldTarget.property(propertyId),
          kind: _jsonEquals(historicalSnapshot.value, currentSnapshot.value)
              ? ObjectHistoryRestoreDecisionKind.noChange
              : ObjectHistoryRestoreDecisionKind.restore,
        ),
      );
    }

    if (scope.kind == ObjectHistoryRestoreScopeKind.wholeObject) {
      addTitleDecision();

      final propertyIds = <int>{
        ...historicalValues.keys,
        ...currentValues.keys,
        ...historicalRelations,
        ...currentRelations,
      }.toList()..sort();
      for (final propertyId in propertyIds) {
        addPropertyDecision(propertyId);
      }

      addBodyDecision();
    } else {
      for (final target in scope.targets) {
        switch (target.kind) {
          case ObjectHistoryFieldKind.title:
            addTitleDecision();
          case ObjectHistoryFieldKind.body:
            addBodyDecision();
          case ObjectHistoryFieldKind.property:
            addPropertyDecision(target.propertyId!);
        }
      }
    }

    return ObjectHistoryCheckpointRestorePreview(
      objectId: historical.entry.objectId,
      historicalRevisionId: historical.entry.revisionId,
      preparedCurrentRevisionId: current.entry.revisionId,
      scope: scope,
      decisions: decisions,
      blockers: blockers,
      relationBlockers: relationBlockers,
    );
  }
}

bool _jsonEquals(dynamic left, dynamic right) {
  if (identical(left, right)) return true;
  if (left == null || right == null) return false;
  if (left is bool && right is bool) return left == right;
  if (left is String && right is String) return left == right;
  if (left is int && right is int) return left == right;
  if (left is double && right is double) return left == right;
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (!_jsonEquals(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_jsonEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return false;
}
