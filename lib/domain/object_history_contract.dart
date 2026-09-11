/// Pure Object-core contract for durable history and restore planning.
///
/// Current canonical Object state remains authoritative. This contract does not
/// persist history, replay Relations, retain managed bytes, or replace local
/// Body Undo/CAS behavior.
enum ObjectHistorySourceKind {
  userMutation,
  systemMutation,
  merge,
  restore,
  typeConversion,
}

/// One immutable durable history checkpoint for an Object.
class ObjectHistoryEntry {
  ObjectHistoryEntry({
    required this.objectId,
    required this.revisionId,
    required this.capturedAt,
    required this.source,
    this.previousRevisionId,
  }) {
    if (objectId <= 0) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'History Object ids must be positive.',
      );
    }
    if (revisionId <= 0) {
      throw ArgumentError.value(
        revisionId,
        'revisionId',
        'History revision ids must be positive.',
      );
    }
    final previous = previousRevisionId;
    if (previous != null && (previous <= 0 || previous >= revisionId)) {
      throw ArgumentError.value(
        previous,
        'previousRevisionId',
        'A previous revision id must be positive and older than revisionId.',
      );
    }
  }

  final int objectId;
  final int revisionId;
  final int? previousRevisionId;
  final DateTime capturedAt;
  final ObjectHistorySourceKind source;
}

enum ObjectHistoryFieldKind { title, property, body }

/// One A-owned field target for selective restore.
class ObjectHistoryFieldTarget {
  ObjectHistoryFieldTarget.title()
    : kind = ObjectHistoryFieldKind.title,
      propertyId = null;

  ObjectHistoryFieldTarget.body()
    : kind = ObjectHistoryFieldKind.body,
      propertyId = null;

  ObjectHistoryFieldTarget.property(int propertyId)
    : kind = ObjectHistoryFieldKind.property,
      propertyId = propertyId {
    if (propertyId <= 0) {
      throw ArgumentError.value(
        propertyId,
        'propertyId',
        'History Property ids must be positive.',
      );
    }
  }

  final ObjectHistoryFieldKind kind;
  final int? propertyId;

  String get key => switch (kind) {
    ObjectHistoryFieldKind.title => 'title',
    ObjectHistoryFieldKind.body => 'body',
    ObjectHistoryFieldKind.property => 'property:$propertyId',
  };
}

enum ObjectHistoryRestoreScopeKind { wholeObject, selective }

/// Restore scope is explicit so a whole checkpoint restore cannot be confused
/// with a focused title/Property/Body restore.
class ObjectHistoryRestoreScope {
  ObjectHistoryRestoreScope.wholeObject()
    : kind = ObjectHistoryRestoreScopeKind.wholeObject,
      targets = const <ObjectHistoryFieldTarget>[];

  ObjectHistoryRestoreScope.selective(
    List<ObjectHistoryFieldTarget> targets,
  ) : kind = ObjectHistoryRestoreScopeKind.selective,
      targets = List<ObjectHistoryFieldTarget>.unmodifiable(targets) {
    if (targets.isEmpty) {
      throw ArgumentError.value(
        targets,
        'targets',
        'Selective history restore requires at least one target.',
      );
    }
    final keys = <String>{};
    for (final target in targets) {
      if (!keys.add(target.key)) {
        throw ArgumentError.value(
          target.key,
          'targets',
          'Selective history restore targets must be unique.',
        );
      }
    }
  }

  final ObjectHistoryRestoreScopeKind kind;
  final List<ObjectHistoryFieldTarget> targets;
}

/// A Relation-layer restore requirement that Lane A cannot satisfy directly.
class ObjectHistoryRelationBlocker {
  ObjectHistoryRelationBlocker({required this.key, required this.reason}) {
    if (key.isEmpty || key.trim() != key) {
      throw ArgumentError.value(
        key,
        'key',
        'Relation history blocker keys must be non-empty and normalized.',
      );
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Relation history blockers require a non-empty explanation.',
      );
    }
  }

  final String key;
  final String reason;
}

/// Conflict-aware restore plan against the current canonical Object revision.
///
/// [expectedCurrentRevisionId] is captured when the restore is prepared.
/// Execution must compare it with [actualCurrentRevisionId] immediately before
/// mutation. Relation blockers remain delegated to canonical Relation integrity.
class ObjectHistoryRestorePlan {
  ObjectHistoryRestorePlan({
    required this.objectId,
    required this.historicalRevisionId,
    required this.expectedCurrentRevisionId,
    required this.actualCurrentRevisionId,
    required this.scope,
    this.relationBlockers = const <ObjectHistoryRelationBlocker>[],
  }) : relationBlockers = List<ObjectHistoryRelationBlocker>.unmodifiable(
         relationBlockers,
       ) {
    if (objectId <= 0) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'Restore Object ids must be positive.',
      );
    }
    if (historicalRevisionId <= 0 ||
        expectedCurrentRevisionId <= 0 ||
        actualCurrentRevisionId <= 0) {
      throw ArgumentError(
        'History restore revision ids must all be positive.',
      );
    }
    if (historicalRevisionId >= expectedCurrentRevisionId) {
      throw ArgumentError(
        'History restore must target a revision older than the prepared current revision.',
      );
    }
  }

  final int objectId;
  final int historicalRevisionId;
  final int expectedCurrentRevisionId;
  final int actualCurrentRevisionId;
  final ObjectHistoryRestoreScope scope;
  final List<ObjectHistoryRelationBlocker> relationBlockers;

  bool get hasCurrentRevisionConflict =>
      expectedCurrentRevisionId != actualCurrentRevisionId;

  bool get isExecutable =>
      !hasCurrentRevisionConflict && relationBlockers.isEmpty;
}

enum ObjectHistoryRetentionKind { keepAll, boundedCheckpoints }

/// Retention intent for later persistence/compaction work.
///
/// This policy covers metadata/checkpoints only. It never grants managed
/// Image/File byte retention or deletion authority; that belongs to Lane F.
class ObjectHistoryRetentionPolicy {
  ObjectHistoryRetentionPolicy.keepAll()
    : kind = ObjectHistoryRetentionKind.keepAll,
      maxCheckpoints = null;

  ObjectHistoryRetentionPolicy.bounded({required int maxCheckpoints})
    : kind = ObjectHistoryRetentionKind.boundedCheckpoints,
      maxCheckpoints = maxCheckpoints {
    if (maxCheckpoints <= 0) {
      throw ArgumentError.value(
        maxCheckpoints,
        'maxCheckpoints',
        'Bounded history retention requires a positive checkpoint limit.',
      );
    }
  }

  final ObjectHistoryRetentionKind kind;
  final int? maxCheckpoints;
}
