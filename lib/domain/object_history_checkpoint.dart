import 'object_body.dart';
import 'object_history_contract.dart';
import 'object_model.dart';

/// One A-owned, persisted-value candidate captured in durable Object history.
///
/// Relation and computed Properties are deliberately rejected here. Relation
/// state belongs to the canonical Relation history path, while computed output
/// is derived from canonical current inputs rather than historical authority.
class ObjectHistoryPropertySnapshot {
  ObjectHistoryPropertySnapshot.fromDefinition({
    required ObjectPropertyDefinition property,
    required dynamic value,
  }) : propertyId = property.id,
       type = property.type,
       value = _freezeJsonValue(value) {
    if (property.id <= 0) {
      throw ArgumentError.value(
        property.id,
        'property',
        'History Property ids must be positive.',
      );
    }
    if (!property.isValue) {
      throw ArgumentError.value(
        property.id,
        'property',
        'Only value Properties belong in the A-owned history checkpoint payload.',
      );
    }
  }

  final int propertyId;
  final ObjectPropertyType type;
  final dynamic value;
}

/// Marker that a Relation Property requires B-owned history handling.
///
/// This intentionally captures no Relation targets, ordering, roles, or edge
/// state. Those semantics remain exclusively behind the canonical Relation
/// subsystem.
class ObjectHistoryRelationRequirement {
  ObjectHistoryRelationRequirement.fromDefinition(
    ObjectPropertyDefinition property,
  ) : propertyId = property.id {
    if (property.id <= 0) {
      throw ArgumentError.value(
        property.id,
        'property',
        'History Relation Property ids must be positive.',
      );
    }
    if (!property.isRelation) {
      throw ArgumentError.value(
        property.id,
        'property',
        'History Relation requirements must reference Relation Properties.',
      );
    }
  }

  final int propertyId;
}

/// Immutable A-owned checkpoint payload attached to one durable history entry.
///
/// Current canonical Object state remains authoritative. This payload defines
/// only the title, value-Property, and Body state that A may later persist for
/// restart-safe inspection/restore. Relation state is represented only as a
/// requirement for the B-owned history path; managed Image/File bytes are not
/// retained or deleted by this contract.
class ObjectHistoryCheckpointPayload {
  ObjectHistoryCheckpointPayload({
    required this.entry,
    required this.title,
    required List<ObjectHistoryPropertySnapshot> propertySnapshots,
    required ObjectBodyDocument body,
    List<ObjectHistoryRelationRequirement> relationRequirements =
        const <ObjectHistoryRelationRequirement>[],
  }) : propertySnapshots = List<ObjectHistoryPropertySnapshot>.unmodifiable(
         propertySnapshots,
       ),
       relationRequirements =
           List<ObjectHistoryRelationRequirement>.unmodifiable(
             relationRequirements,
           ),
       _bodyJson = _freezeBody(body) {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'History checkpoint title must not be empty.',
      );
    }

    final propertyIds = <int>{};
    for (final snapshot in propertySnapshots) {
      if (!propertyIds.add(snapshot.propertyId)) {
        throw ArgumentError.value(
          snapshot.propertyId,
          'propertySnapshots',
          'History checkpoint Property ids must be unique.',
        );
      }
    }

    final relationIds = <int>{};
    for (final requirement in relationRequirements) {
      if (!relationIds.add(requirement.propertyId)) {
        throw ArgumentError.value(
          requirement.propertyId,
          'relationRequirements',
          'History Relation requirement Property ids must be unique.',
        );
      }
      if (propertyIds.contains(requirement.propertyId)) {
        throw ArgumentError.value(
          requirement.propertyId,
          'relationRequirements',
          'A Property cannot be both an A-owned value snapshot and a Relation requirement.',
        );
      }
    }
  }

  final ObjectHistoryEntry entry;
  final String title;
  final List<ObjectHistoryPropertySnapshot> propertySnapshots;
  final List<ObjectHistoryRelationRequirement> relationRequirements;
  final Map<String, dynamic> _bodyJson;

  /// Returns a fresh Body document so caller mutation cannot alter the stored
  /// checkpoint representation.
  ObjectBodyDocument get body => ObjectBodyDocument.fromJson(_bodyJson);
}

Map<String, dynamic> _freezeBody(ObjectBodyDocument body) {
  final frozen = _freezeJsonValue(body.toJson());
  return frozen as Map<String, dynamic>;
}

dynamic _freezeJsonValue(dynamic value) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw const FormatException(
        'History checkpoint values must contain only finite JSON numbers.',
      );
    }
    return value;
  }
  if (value is num) return value;
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map(_freezeJsonValue));
  }
  if (value is Map) {
    final frozen = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const FormatException(
          'History checkpoint JSON object keys must be strings.',
        );
      }
      frozen[key] = _freezeJsonValue(entry.value);
    }
    return Map<String, dynamic>.unmodifiable(frozen);
  }
  throw FormatException(
    'History checkpoint values must be JSON-safe; found ${value.runtimeType}.',
  );
}
