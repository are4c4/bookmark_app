import 'object_history_contract.dart';

enum ObjectHistoryRelationOrdering { explicitTargetOrder }

enum ObjectHistoryRelationPairRole { source, inverse }

/// Immutable B-owned evidence for one Relation Property at one history point.
///
/// [targetObjectIds] are historical identities in their exact stored order.
/// They are never rewritten when a retired target later redirects elsewhere.
class ObjectHistoryRelationSnapshot {
  ObjectHistoryRelationSnapshot({
    required this.sourceObjectId,
    required this.sourceObjectTypeId,
    required this.propertyId,
    required this.targetObjectTypeId,
    required this.allowsMultipleRelations,
    required List<int> targetObjectIds,
    this.ordering = ObjectHistoryRelationOrdering.explicitTargetOrder,
    this.inversePropertyId,
    this.pairRole,
    this.inverseAllowsMultipleRelations,
  }) : targetObjectIds = List<int>.unmodifiable(targetObjectIds) {
    if (sourceObjectId <= 0 ||
        sourceObjectTypeId <= 0 ||
        propertyId <= 0 ||
        targetObjectTypeId <= 0) {
      throw ArgumentError('Relation history ids must all be positive.');
    }
    if (targetObjectIds.any((id) => id <= 0)) {
      throw ArgumentError.value(
        targetObjectIds,
        'targetObjectIds',
        'Historical Relation target ids must all be positive.',
      );
    }
    if (targetObjectIds.toSet().length != targetObjectIds.length) {
      throw ArgumentError.value(
        targetObjectIds,
        'targetObjectIds',
        'Historical Relation targets must preserve canonical unique identities.',
      );
    }
    if (!allowsMultipleRelations && targetObjectIds.length > 1) {
      throw ArgumentError.value(
        targetObjectIds,
        'targetObjectIds',
        'A single Relation history snapshot cannot contain multiple targets.',
      );
    }

    final pairFields = <Object?>[
      inversePropertyId,
      pairRole,
      inverseAllowsMultipleRelations,
    ];
    final hasAnyPairField = pairFields.any((value) => value != null);
    final hasAllPairFields = pairFields.every((value) => value != null);
    if (hasAnyPairField != hasAllPairFields) {
      throw ArgumentError(
        'Bidirectional Relation history metadata must be complete or absent.',
      );
    }
    final inverseId = inversePropertyId;
    if (inverseId != null && (inverseId <= 0 || inverseId == propertyId)) {
      throw ArgumentError.value(
        inverseId,
        'inversePropertyId',
        'Inverse Relation Property id must be positive and distinct.',
      );
    }
  }

  factory ObjectHistoryRelationSnapshot.fromJson(Map<String, dynamic> json) {
    final rawTargets = json['targetObjectIds'];
    if (rawTargets is! List || rawTargets.any((value) => value is! int)) {
      throw const FormatException(
        'Relation history targetObjectIds must be an integer list.',
      );
    }

    final ordering = switch (json['ordering']) {
      'explicitTargetOrder' =>
        ObjectHistoryRelationOrdering.explicitTargetOrder,
      _ => throw const FormatException(
        'Unsupported Relation history ordering contract.',
      ),
    };
    final rawPairRole = json['pairRole'];
    final pairRole = switch (rawPairRole) {
      null => null,
      'source' => ObjectHistoryRelationPairRole.source,
      'inverse' => ObjectHistoryRelationPairRole.inverse,
      _ => throw const FormatException(
        'Unsupported Relation history bidirectional pair role.',
      ),
    };

    return ObjectHistoryRelationSnapshot(
      sourceObjectId: _requiredPositiveInt(json, 'sourceObjectId'),
      sourceObjectTypeId: _requiredPositiveInt(json, 'sourceObjectTypeId'),
      propertyId: _requiredPositiveInt(json, 'propertyId'),
      targetObjectTypeId: _requiredPositiveInt(json, 'targetObjectTypeId'),
      allowsMultipleRelations: _requiredBool(json, 'allowsMultipleRelations'),
      targetObjectIds: rawTargets.cast<int>(),
      ordering: ordering,
      inversePropertyId: _optionalPositiveInt(json, 'inversePropertyId'),
      pairRole: pairRole,
      inverseAllowsMultipleRelations: _optionalBool(
        json,
        'inverseAllowsMultipleRelations',
      ),
    );
  }

  final int sourceObjectId;
  final int sourceObjectTypeId;
  final int propertyId;
  final int targetObjectTypeId;
  final bool allowsMultipleRelations;
  final List<int> targetObjectIds;
  final ObjectHistoryRelationOrdering ordering;
  final int? inversePropertyId;
  final ObjectHistoryRelationPairRole? pairRole;
  final bool? inverseAllowsMultipleRelations;

  bool get isBidirectional => inversePropertyId != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceObjectId': sourceObjectId,
    'sourceObjectTypeId': sourceObjectTypeId,
    'propertyId': propertyId,
    'targetObjectTypeId': targetObjectTypeId,
    'allowsMultipleRelations': allowsMultipleRelations,
    'targetObjectIds': List<int>.of(targetObjectIds),
    'ordering': 'explicitTargetOrder',
    'inversePropertyId': inversePropertyId,
    'pairRole': switch (pairRole) {
      ObjectHistoryRelationPairRole.source => 'source',
      ObjectHistoryRelationPairRole.inverse => 'inverse',
      null => null,
    },
    'inverseAllowsMultipleRelations': inverseAllowsMultipleRelations,
  };
}

/// One explicit planning-time resolution from historical evidence to a current
/// canonical Object identity.
class ObjectHistoryRelationTargetResolution {
  const ObjectHistoryRelationTargetResolution({
    required this.historicalTargetObjectId,
    required this.currentTargetObjectId,
  });

  final int historicalTargetObjectId;
  final int currentTargetObjectId;

  bool get wasRedirected => historicalTargetObjectId != currentTargetObjectId;
}

/// Conflict-aware B-owned plan for restoring one historical Relation value.
class ObjectHistoryRelationRestorePlan {
  ObjectHistoryRelationRestorePlan({
    required this.workspaceId,
    required this.historical,
    required List<int> beforeTargetObjectIds,
    required List<ObjectHistoryRelationTargetResolution> targetResolutions,
    required List<ObjectHistoryRelationBlocker> blockers,
    required List<int> changedObjectIds,
  }) : beforeTargetObjectIds = List<int>.unmodifiable(beforeTargetObjectIds),
       targetResolutions =
           List<ObjectHistoryRelationTargetResolution>.unmodifiable(
             targetResolutions,
           ),
       blockers = List<ObjectHistoryRelationBlocker>.unmodifiable(blockers),
       changedObjectIds = List<int>.unmodifiable(changedObjectIds) {
    if (workspaceId <= 0) {
      throw ArgumentError.value(
        workspaceId,
        'workspaceId',
        'History restore workspace id must be positive.',
      );
    }
  }

  final int workspaceId;
  final ObjectHistoryRelationSnapshot historical;
  final List<int> beforeTargetObjectIds;
  final List<ObjectHistoryRelationTargetResolution> targetResolutions;
  final List<ObjectHistoryRelationBlocker> blockers;
  final List<int> changedObjectIds;

  List<int> get afterTargetObjectIds => List<int>.unmodifiable(
    targetResolutions.map((resolution) => resolution.currentTargetObjectId),
  );

  bool get isExecutable => blockers.isEmpty;

  bool get hasChanges =>
      !_sameIntList(beforeTargetObjectIds, afterTargetObjectIds);

  Map<int, int> get explicitRedirectResolutions => <int, int>{
    for (final resolution in targetResolutions)
      if (resolution.wasRedirected)
        resolution.historicalTargetObjectId: resolution.currentTargetObjectId,
  };
}

class ObjectHistoryRelationRestoreImpact {
  ObjectHistoryRelationRestoreImpact({required List<int> changedObjectIds})
    : changedObjectIds = List<int>.unmodifiable(changedObjectIds);

  final List<int> changedObjectIds;
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('Relation history $key must be a positive integer.');
  }
  return value;
}

int? _optionalPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int || value <= 0) {
    throw FormatException(
      'Relation history $key must be null or a positive integer.',
    );
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Relation history $key must be a bool.');
  }
  return value;
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! bool) {
    throw FormatException('Relation history $key must be null or a bool.');
  }
  return value;
}

bool _sameIntList(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
