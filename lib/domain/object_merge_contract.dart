/// Pure Object-core contract for explicit duplicate merge planning.
///
/// This file deliberately contains no persistence, Relation mutation, Search,
/// View, or managed-file behavior. It only describes when an explicit merge is
/// safe to execute and how retired Object ids resolve after a later persistence
/// layer records redirects.
enum ObjectMergeStateKind { title, property, body, aliases, lifecycle }

enum ObjectMergeDecision { keepSurvivor, takeRetired, combine }

enum ObjectMergeRequirementStatus { compatible, decisionRequired }

/// One A-owned state dimension considered by an Object merge preview.
class ObjectMergeRequirement {
  ObjectMergeRequirement.compatible({required this.key, required this.kind})
    : status = ObjectMergeRequirementStatus.compatible,
      allowedDecisions = const <ObjectMergeDecision>{} {
    _validateKey(key);
  }

  ObjectMergeRequirement.conflict({
    required this.key,
    required this.kind,
    required Set<ObjectMergeDecision> allowedDecisions,
  }) : status = ObjectMergeRequirementStatus.decisionRequired,
       allowedDecisions = Set<ObjectMergeDecision>.unmodifiable(
         allowedDecisions,
       ) {
    _validateKey(key);
    if (allowedDecisions.isEmpty) {
      throw ArgumentError.value(
        allowedDecisions,
        'allowedDecisions',
        'A merge conflict must expose at least one explicit resolution.',
      );
    }
  }

  final String key;
  final ObjectMergeStateKind kind;
  final ObjectMergeRequirementStatus status;
  final Set<ObjectMergeDecision> allowedDecisions;

  bool get requiresDecision =>
      status == ObjectMergeRequirementStatus.decisionRequired;

  static void _validateKey(String key) {
    if (key.isEmpty || key.trim() != key) {
      throw ArgumentError.value(
        key,
        'key',
        'Merge requirement keys must be non-empty and already normalized.',
      );
    }
  }
}

/// A Relation-layer conflict that A cannot resolve by choosing Object state.
class ObjectMergeRelationBlocker {
  ObjectMergeRelationBlocker({required this.key, required this.reason}) {
    if (key.isEmpty || key.trim() != key) {
      throw ArgumentError.value(
        key,
        'key',
        'Relation blocker keys must be non-empty and already normalized.',
      );
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Relation blockers require a non-empty explanation.',
      );
    }
  }

  final String key;
  final String reason;
}

/// Read-only preview of one explicit Object merge.
class ObjectMergePreview {
  ObjectMergePreview({
    required this.survivorId,
    required this.retiredId,
    List<ObjectMergeRequirement> requirements =
        const <ObjectMergeRequirement>[],
    List<ObjectMergeRelationBlocker> relationBlockers =
        const <ObjectMergeRelationBlocker>[],
  }) : requirements = List<ObjectMergeRequirement>.unmodifiable(requirements),
       relationBlockers = List<ObjectMergeRelationBlocker>.unmodifiable(
         relationBlockers,
       ) {
    _validateObjectIds(survivorId: survivorId, retiredId: retiredId);
    final keys = <String>{};
    for (final requirement in requirements) {
      if (!keys.add(requirement.key)) {
        throw ArgumentError.value(
          requirement.key,
          'requirements',
          'Merge requirement keys must be unique.',
        );
      }
    }
  }

  final int survivorId;
  final int retiredId;
  final List<ObjectMergeRequirement> requirements;
  final List<ObjectMergeRelationBlocker> relationBlockers;

  bool get hasRelationBlockers => relationBlockers.isNotEmpty;

  ObjectMergePlan plan({
    Map<String, ObjectMergeDecision> decisions =
        const <String, ObjectMergeDecision>{},
  }) {
    return ObjectMergePlan(preview: this, decisions: decisions);
  }
}

/// Explicit merge decisions applied to a preview.
///
/// This does not mutate Objects. A later persistence implementation may execute
/// only a plan whose [isExecutable] value is true.
class ObjectMergePlan {
  ObjectMergePlan({
    required this.preview,
    Map<String, ObjectMergeDecision> decisions =
        const <String, ObjectMergeDecision>{},
  }) : decisions = Map<String, ObjectMergeDecision>.unmodifiable(decisions) {
    final requirementsByKey = <String, ObjectMergeRequirement>{
      for (final requirement in preview.requirements)
        requirement.key: requirement,
    };
    for (final entry in decisions.entries) {
      final requirement = requirementsByKey[entry.key];
      if (requirement == null || !requirement.requiresDecision) {
        throw ArgumentError.value(
          entry.key,
          'decisions',
          'A decision may target only an unresolved merge requirement.',
        );
      }
      if (!requirement.allowedDecisions.contains(entry.value)) {
        throw ArgumentError.value(
          entry.value,
          'decisions',
          'The selected merge decision is not allowed for ${entry.key}.',
        );
      }
    }
  }

  final ObjectMergePreview preview;
  final Map<String, ObjectMergeDecision> decisions;

  bool get isExecutable {
    if (preview.hasRelationBlockers) return false;
    for (final requirement in preview.requirements) {
      if (requirement.requiresDecision &&
          !decisions.containsKey(requirement.key)) {
        return false;
      }
    }
    return true;
  }

  ObjectMergePlan withDecision(String key, ObjectMergeDecision decision) {
    return ObjectMergePlan(
      preview: preview,
      decisions: <String, ObjectMergeDecision>{...decisions, key: decision},
    );
  }
}

/// Resolves historical retired Object ids to the final canonical Object id.
///
/// The whole redirect map is validated before resolution so corruption in an
/// unrelated chain is not silently ignored. Persistence is intentionally out of
/// scope for this contract-only slice.
class ObjectRedirectResolver {
  const ObjectRedirectResolver();

  int resolve({required int objectId, required Map<int, int> redirects}) {
    if (objectId <= 0) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'Object ids must be positive.',
      );
    }
    _validateRedirects(redirects);

    var current = objectId;
    while (redirects.containsKey(current)) {
      current = redirects[current]!;
    }
    return current;
  }

  void _validateRedirects(Map<int, int> redirects) {
    for (final entry in redirects.entries) {
      if (entry.key <= 0 || entry.value <= 0) {
        throw StateError('Object redirects require positive ids.');
      }
      if (entry.key == entry.value) {
        throw StateError('Object redirects cannot point an id to itself.');
      }
    }

    final states = <int, int>{};
    for (final start in redirects.keys) {
      _visit(start, redirects, states);
    }
  }

  void _visit(int objectId, Map<int, int> redirects, Map<int, int> states) {
    final state = states[objectId] ?? 0;
    if (state == 2) return;
    if (state == 1) {
      throw StateError('Object redirect cycle detected.');
    }

    states[objectId] = 1;
    final next = redirects[objectId];
    if (next != null && redirects.containsKey(next)) {
      _visit(next, redirects, states);
    }
    states[objectId] = 2;
  }
}

void _validateObjectIds({required int survivorId, required int retiredId}) {
  if (survivorId <= 0 || retiredId <= 0) {
    throw ArgumentError('Merge Object ids must be positive.');
  }
  if (survivorId == retiredId) {
    throw ArgumentError('Merge survivor and retired Object ids must differ.');
  }
}
