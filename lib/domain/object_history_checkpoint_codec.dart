import 'object_body.dart';
import 'object_history_checkpoint.dart';
import 'object_history_contract.dart';
import 'object_model.dart';

/// Versioned serialization boundary for A-owned durable Object checkpoints.
///
/// This codec intentionally stores only A-owned value state plus Relation
/// Property requirements. Canonical Relation targets/order/edge state remain
/// B-owned and managed-byte retention remains F-owned.
class ObjectHistoryCheckpointCodec {
  const ObjectHistoryCheckpointCodec();

  static const int schemaVersion = 1;

  Map<String, dynamic> encode(ObjectHistoryCheckpointPayload payload) =>
      <String, dynamic>{
        'schemaVersion': schemaVersion,
        'entry': <String, dynamic>{
          'objectId': payload.entry.objectId,
          'revisionId': payload.entry.revisionId,
          'previousRevisionId': payload.entry.previousRevisionId,
          'capturedAt': payload.entry.capturedAt.toUtc().toIso8601String(),
          'source': payload.entry.source.name,
        },
        'title': payload.title,
        'properties': <Map<String, dynamic>>[
          for (final snapshot in payload.propertySnapshots)
            <String, dynamic>{
              'propertyId': snapshot.propertyId,
              'type': snapshot.type.name,
              'value': snapshot.value,
            },
        ],
        'body': payload.body.toJson(),
        'relationPropertyIds': <int>[
          for (final requirement in payload.relationRequirements)
            requirement.propertyId,
        ],
      };

  ObjectHistoryCheckpointPayload decode(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != schemaVersion) {
      throw FormatException(
        'Unsupported Object history checkpoint schemaVersion: $version.',
      );
    }

    final entryJson = _stringMap(json['entry'], 'entry');
    final objectId = _positiveInt(entryJson['objectId'], 'entry.objectId');
    final revisionId = _positiveInt(
      entryJson['revisionId'],
      'entry.revisionId',
    );
    final previousRaw = entryJson['previousRevisionId'];
    final previousRevisionId = previousRaw == null
        ? null
        : _positiveInt(previousRaw, 'entry.previousRevisionId');
    final capturedAtRaw = entryJson['capturedAt'];
    if (capturedAtRaw is! String) {
      throw const FormatException('entry.capturedAt must be a string.');
    }
    final capturedAt = DateTime.tryParse(capturedAtRaw);
    if (capturedAt == null) {
      throw FormatException(
        'Invalid Object history checkpoint timestamp: $capturedAtRaw.',
      );
    }
    final source = _enumByName<ObjectHistorySourceKind>(
      ObjectHistorySourceKind.values,
      entryJson['source'],
      'entry.source',
    );

    final title = json['title'];
    if (title is! String) {
      throw const FormatException('title must be a string.');
    }

    final propertiesRaw = json['properties'];
    if (propertiesRaw is! List) {
      throw const FormatException('properties must be a list.');
    }
    final propertySnapshots = <ObjectHistoryPropertySnapshot>[];
    for (var index = 0; index < propertiesRaw.length; index++) {
      final propertyJson = _stringMap(
        propertiesRaw[index],
        'properties[$index]',
      );
      final propertyId = _positiveInt(
        propertyJson['propertyId'],
        'properties[$index].propertyId',
      );
      final type = _enumByName<ObjectPropertyType>(
        ObjectPropertyType.values,
        propertyJson['type'],
        'properties[$index].type',
      );
      final definition = ObjectPropertyDefinition(
        id: propertyId,
        objectTypeId: 1,
        name: 'Historical Property $propertyId',
        type: type,
        sortOrder: index,
      );
      if (!definition.isValue) {
        throw FormatException(
          'A-owned history checkpoint Property $propertyId must use a value Property type.',
        );
      }
      propertySnapshots.add(
        ObjectHistoryPropertySnapshot.fromDefinition(
          property: definition,
          value: propertyJson['value'],
        ),
      );
    }

    final bodyJson = _stringMap(json['body'], 'body');
    final body = ObjectBodyDocument.fromJson(bodyJson);

    final relationsRaw = json['relationPropertyIds'];
    if (relationsRaw is! List) {
      throw const FormatException('relationPropertyIds must be a list.');
    }
    final relationRequirements = <ObjectHistoryRelationRequirement>[];
    for (var index = 0; index < relationsRaw.length; index++) {
      final propertyId = _positiveInt(
        relationsRaw[index],
        'relationPropertyIds[$index]',
      );
      relationRequirements.add(
        ObjectHistoryRelationRequirement.fromDefinition(
          ObjectPropertyDefinition(
            id: propertyId,
            objectTypeId: 1,
            name: 'Historical Relation $propertyId',
            type: ObjectPropertyType.objectRelation,
            sortOrder: index,
          ),
        ),
      );
    }

    return ObjectHistoryCheckpointPayload(
      entry: ObjectHistoryEntry(
        objectId: objectId,
        revisionId: revisionId,
        previousRevisionId: previousRevisionId,
        capturedAt: capturedAt.toUtc(),
        source: source,
      ),
      title: title,
      propertySnapshots: propertySnapshots,
      body: body,
      relationRequirements: relationRequirements,
    );
  }
}

Map<String, dynamic> _stringMap(dynamic value, String path) {
  if (value is! Map) {
    throw FormatException('$path must be a JSON object.');
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$path must contain only string keys.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

int _positiveInt(dynamic value, String path) {
  if (value is! int || value <= 0) {
    throw FormatException('$path must be a positive integer.');
  }
  return value;
}

T _enumByName<T extends Enum>(List<T> values, dynamic value, String path) {
  if (value is! String) {
    throw FormatException('$path must be a string.');
  }
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw FormatException('Unknown $path value: $value.');
}
