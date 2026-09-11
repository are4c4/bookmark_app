import 'object_alias.dart';
import 'object_body.dart';
import 'object_merge_contract.dart';
import 'object_model.dart';

/// Immutable A-owned value Property state used by explicit Object merge
/// planning.
///
/// Relation and computed Properties are deliberately rejected. Relation state
/// belongs to B-owned merge planning, while computed output is derived rather
/// than authoritative persisted input.
class ObjectMergeValuePropertySnapshot {
  ObjectMergeValuePropertySnapshot.fromDefinition({
    required ObjectPropertyDefinition property,
    required dynamic value,
  }) : propertyId = property.id,
       type = property.type,
       value = _freezeJsonValue(value) {
    if (property.id <= 0) {
      throw ArgumentError.value(
        property.id,
        'property',
        'Merge Property ids must be positive.',
      );
    }
    if (!property.isValue) {
      throw ArgumentError.value(
        property.id,
        'property',
        'Only A-owned value Properties belong in Object merge state.',
      );
    }
  }

  final int propertyId;
  final ObjectPropertyType type;
  final dynamic value;
}

/// Immutable concrete A-owned state for one Object before an explicit merge.
class ObjectMergeStateSnapshot {
  ObjectMergeStateSnapshot({
    required this.objectId,
    required this.objectTypeId,
    required this.title,
    required List<ObjectMergeValuePropertySnapshot> propertySnapshots,
    required ObjectBodyDocument body,
    required List<String> aliases,
  }) : propertySnapshots = List<ObjectMergeValuePropertySnapshot>.unmodifiable(
         propertySnapshots,
       ),
       aliases = List<String>.unmodifiable(aliases),
       _bodyJson = _freezeBody(body) {
    if (objectId <= 0) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'Merge Object ids must be positive.',
      );
    }
    if (objectTypeId <= 0) {
      throw ArgumentError.value(
        objectTypeId,
        'objectTypeId',
        'Merge ObjectType ids must be positive.',
      );
    }

    final propertyIds = <int>{};
    for (final snapshot in propertySnapshots) {
      if (!propertyIds.add(snapshot.propertyId)) {
        throw ArgumentError.value(
          snapshot.propertyId,
          'propertySnapshots',
          'Merge Property ids must be unique within one Object snapshot.',
        );
      }
    }

    final canonicalAliases = canonicalizeObjectAliases(aliases);
    if (!_sameStringList(aliases, canonicalAliases)) {
      throw ArgumentError.value(
        aliases,
        'aliases',
        'Merge aliases must already satisfy canonical Object alias storage semantics.',
      );
    }
  }

  final int objectId;
  final int objectTypeId;
  final String title;
  final List<ObjectMergeValuePropertySnapshot> propertySnapshots;
  final List<String> aliases;
  final Map<String, dynamic> _bodyJson;

  /// Returns a fresh Body document so caller mutation cannot alter the
  /// prepared merge snapshot.
  ObjectBodyDocument get body => ObjectBodyDocument.fromJson(_bodyJson);
}

/// Pure planner that derives the existing [ObjectMergePreview] contract from
/// concrete A-owned Object state.
///
/// It intentionally performs no persistence and does not inspect Relation
/// state. B-owned Relation blockers can be added by the later merge
/// coordinator before execution.
class ObjectMergeStatePlanner {
  const ObjectMergeStatePlanner();

  ObjectMergePreview preview({
    required ObjectMergeStateSnapshot survivor,
    required ObjectMergeStateSnapshot retired,
    List<ObjectMergeRelationBlocker> relationBlockers =
        const <ObjectMergeRelationBlocker>[],
  }) {
    if (survivor.objectId == retired.objectId) {
      throw ArgumentError('Merge survivor and retired Object ids must differ.');
    }
    if (survivor.objectTypeId != retired.objectTypeId) {
      throw StateError(
        'Objects of different ObjectTypes cannot be merged without an explicit type-conversion contract.',
      );
    }

    final survivorProperties = _propertiesById(survivor.propertySnapshots);
    final retiredProperties = _propertiesById(retired.propertySnapshots);
    final survivorIds = survivorProperties.keys.toSet();
    final retiredIds = retiredProperties.keys.toSet();
    if (!_sameIntSet(survivorIds, retiredIds)) {
      throw StateError(
        'Object merge requires identical A-owned value Property identity sets.',
      );
    }

    final requirements = <ObjectMergeRequirement>[
      _textRequirement(
        key: 'title',
        kind: ObjectMergeStateKind.title,
        survivorValue: survivor.title,
        retiredValue: retired.title,
      ),
    ];

    final propertyIds = survivorIds.toList()..sort();
    for (final propertyId in propertyIds) {
      final survivorProperty = survivorProperties[propertyId]!;
      final retiredProperty = retiredProperties[propertyId]!;
      if (survivorProperty.type != retiredProperty.type) {
        throw StateError(
          'Object merge Property $propertyId changed type between snapshots.',
        );
      }
      requirements.add(
        _jsonRequirement(
          key: 'property:$propertyId',
          kind: ObjectMergeStateKind.property,
          survivorValue: survivorProperty.value,
          retiredValue: retiredProperty.value,
        ),
      );
    }

    requirements.add(
      _jsonRequirement(
        key: 'body',
        kind: ObjectMergeStateKind.body,
        survivorValue: survivor._bodyJson,
        retiredValue: retired._bodyJson,
      ),
    );
    requirements.add(_aliasRequirement(survivor, retired));

    // Generic created/updated lifecycle metadata belongs to the surviving
    // identity. This slice records that policy as compatible and never mutates
    // lifecycle state.
    requirements.add(
      ObjectMergeRequirement.compatible(
        key: 'lifecycle',
        kind: ObjectMergeStateKind.lifecycle,
      ),
    );

    return ObjectMergePreview(
      survivorId: survivor.objectId,
      retiredId: retired.objectId,
      requirements: requirements,
      relationBlockers: relationBlockers,
    );
  }

  /// Deterministic alias result for an explicit `combine` decision.
  ///
  /// Survivor order is retained and previously unseen retired aliases are
  /// appended in retired order. A normalized spelling collision with different
  /// display text cannot preserve both spellings under ObjectAliasStore
  /// semantics, so such a combination fails closed.
  List<String> combineAliases({
    required ObjectMergeStateSnapshot survivor,
    required ObjectMergeStateSnapshot retired,
  }) {
    if (survivor.objectTypeId != retired.objectTypeId) {
      throw StateError('Cannot combine aliases across ObjectTypes.');
    }
    if (!_aliasesCanCombine(survivor.aliases, retired.aliases)) {
      throw StateError(
        'Alias display spellings conflict after normalization; choose one side explicitly.',
      );
    }

    final result = <String>[...survivor.aliases];
    final seen = survivor.aliases.map(normalizeObjectAlias).toSet();
    for (final alias in retired.aliases) {
      if (seen.add(normalizeObjectAlias(alias))) result.add(alias);
    }
    return List<String>.unmodifiable(result);
  }

  Map<int, ObjectMergeValuePropertySnapshot> _propertiesById(
    List<ObjectMergeValuePropertySnapshot> snapshots,
  ) => <int, ObjectMergeValuePropertySnapshot>{
    for (final snapshot in snapshots) snapshot.propertyId: snapshot,
  };

  ObjectMergeRequirement _textRequirement({
    required String key,
    required ObjectMergeStateKind kind,
    required String survivorValue,
    required String retiredValue,
  }) {
    if (survivorValue == retiredValue) {
      return ObjectMergeRequirement.compatible(key: key, kind: kind);
    }
    return ObjectMergeRequirement.conflict(
      key: key,
      kind: kind,
      allowedDecisions: const <ObjectMergeDecision>{
        ObjectMergeDecision.keepSurvivor,
        ObjectMergeDecision.takeRetired,
      },
    );
  }

  ObjectMergeRequirement _jsonRequirement({
    required String key,
    required ObjectMergeStateKind kind,
    required dynamic survivorValue,
    required dynamic retiredValue,
  }) {
    if (_deepJsonEquals(survivorValue, retiredValue)) {
      return ObjectMergeRequirement.compatible(key: key, kind: kind);
    }
    return ObjectMergeRequirement.conflict(
      key: key,
      kind: kind,
      allowedDecisions: const <ObjectMergeDecision>{
        ObjectMergeDecision.keepSurvivor,
        ObjectMergeDecision.takeRetired,
      },
    );
  }

  ObjectMergeRequirement _aliasRequirement(
    ObjectMergeStateSnapshot survivor,
    ObjectMergeStateSnapshot retired,
  ) {
    if (_sameStringList(survivor.aliases, retired.aliases)) {
      return ObjectMergeRequirement.compatible(
        key: 'aliases',
        kind: ObjectMergeStateKind.aliases,
      );
    }

    final allowed = <ObjectMergeDecision>{
      ObjectMergeDecision.keepSurvivor,
      ObjectMergeDecision.takeRetired,
    };
    if (_aliasesCanCombine(survivor.aliases, retired.aliases)) {
      allowed.add(ObjectMergeDecision.combine);
    }
    return ObjectMergeRequirement.conflict(
      key: 'aliases',
      kind: ObjectMergeStateKind.aliases,
      allowedDecisions: allowed,
    );
  }
}

bool _aliasesCanCombine(List<String> survivor, List<String> retired) {
  final displayByNormalized = <String, String>{};
  for (final alias in <String>[...survivor, ...retired]) {
    final normalized = normalizeObjectAlias(alias);
    final existing = displayByNormalized[normalized];
    if (existing != null && existing != alias) return false;
    displayByNormalized[normalized] = alias;
  }
  return true;
}

bool _sameStringList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameIntSet(Set<int> left, Set<int> right) =>
    left.length == right.length && left.containsAll(right);

Map<String, dynamic> _freezeBody(ObjectBodyDocument body) =>
    _freezeJsonValue(body.toJson()) as Map<String, dynamic>;

dynamic _freezeJsonValue(dynamic value) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw const FormatException(
        'Merge state values must contain only finite JSON numbers.',
      );
    }
    return value;
  }
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map(_freezeJsonValue));
  }
  if (value is Map) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException(
          'Merge state JSON object keys must be strings.',
        );
      }
      result[entry.key as String] = _freezeJsonValue(entry.value);
    }
    return Map<String, dynamic>.unmodifiable(result);
  }
  throw FormatException(
    'Merge state values must be JSON-safe; found ${value.runtimeType}.',
  );
}

bool _deepJsonEquals(dynamic left, dynamic right) {
  if (left is int || left is double) {
    if (right.runtimeType != left.runtimeType) return false;
    return left == right;
  }
  if (left == null || left is bool || left is String) return left == right;
  if (left is List) {
    if (right is! List || left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepJsonEquals(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map<String, dynamic>) {
    if (right is! Map<String, dynamic> || left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepJsonEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return false;
}
