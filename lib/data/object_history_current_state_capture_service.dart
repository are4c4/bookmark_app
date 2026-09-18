import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/object_body.dart';
import '../domain/object_history_checkpoint.dart';
import '../domain/object_history_contract.dart';
import '../domain/object_history_relation.dart';
import '../domain/object_model.dart';
import 'bidirectional_relation_store.dart';
import 'generic_database_store.dart';
import 'object_body_store.dart';
import 'object_history_capture_coordinator.dart';
import 'object_history_checkpoint_loader.dart';
import 'object_history_checkpoint_store.dart';
import 'object_history_relation_service.dart';
import 'object_store.dart';
import 'relation_mutation_service.dart';

/// Result of capturing the current canonical Object state into durable history.
class ObjectHistoryCurrentStateCaptureResult {
  const ObjectHistoryCurrentStateCaptureResult({
    required this.revisionId,
    required this.appended,
  });

  final int revisionId;
  final bool appended;
}

/// A-owned production capture boundary for durable whole-Object history.
///
/// Current Object/Value/Body state is read from canonical A-owned stores.
/// Relation targets/order are captured only through B's history service.
/// Persistence is delegated to [ObjectHistoryCaptureCoordinator], which keeps
/// the A checkpoint and B Relation snapshots atomic.
class ObjectHistoryCurrentStateCaptureService {
  ObjectHistoryCurrentStateCaptureService({
    required GenericDatabaseStore genericStore,
    required ObjectBodyStore bodyStore,
    required ObjectHistoryRelationService relationService,
    DateTime Function()? clock,
  }) : _genericStore = genericStore,
       _bodyStore = bodyStore,
       _relationService = relationService,
       _clock = clock ?? DateTime.now,
       _checkpointStore = ObjectHistoryCheckpointStore(genericStore),
       _loader = ObjectHistoryCheckpointLoader(genericStore),
       _coordinator = ObjectHistoryCaptureCoordinator(genericStore);

  factory ObjectHistoryCurrentStateCaptureService.fromStores({
    required GenericDatabaseStore genericStore,
    required ObjectStore objectStore,
    ObjectBodyStore? bodyStore,
    DateTime Function()? clock,
  }) {
    final bidirectionalStore = BidirectionalRelationStore(
      genericStore: genericStore,
      objectStore: objectStore,
    );
    final mutationService = RelationMutationService(
      objectStore: objectStore,
      bidirectionalStore: bidirectionalStore,
      genericStore: genericStore,
    );
    return ObjectHistoryCurrentStateCaptureService(
      genericStore: genericStore,
      bodyStore: bodyStore ?? ObjectBodyStore(genericStore),
      relationService: ObjectHistoryRelationService(
        objectStore: objectStore,
        bidirectionalStore: bidirectionalStore,
        mutationService: mutationService,
        genericStore: genericStore,
      ),
      clock: clock,
    );
  }

  final GenericDatabaseStore _genericStore;
  final ObjectBodyStore _bodyStore;
  final ObjectHistoryRelationService _relationService;
  final DateTime Function() _clock;
  final ObjectHistoryCheckpointStore _checkpointStore;
  final ObjectHistoryCheckpointLoader _loader;
  final ObjectHistoryCaptureCoordinator _coordinator;

  Future<T> captureBeforeMutation<T>({
    required int objectTypeId,
    required int objectId,
    ObjectHistorySourceKind source = ObjectHistorySourceKind.userMutation,
    required Future<T> Function() mutation,
  }) {
    return _genericStore.database.transaction(() async {
      await captureCurrent(
        objectTypeId: objectTypeId,
        objectId: objectId,
        source: source,
      );
      return mutation();
    });
  }

  Future<ObjectHistoryCurrentStateCaptureResult> captureCurrent({
    required int objectTypeId,
    required int objectId,
    ObjectHistorySourceKind source = ObjectHistorySourceKind.userMutation,
  }) {
    _validatePositiveId(objectTypeId, 'objectTypeId');
    _validatePositiveId(objectId, 'objectId');

    return _genericStore.database.transaction(() async {
      final current = await _readCurrentEvidence(
        objectTypeId: objectTypeId,
        objectId: objectId,
      );
      final latest = await _checkpointStore.latest(objectId);

      if (latest != null) {
        final whole = await _loader.load(
          objectId: objectId,
          revisionId: latest.entry.revisionId,
        );
        if (whole == null) {
          throw StateError(
            'Latest Object history checkpoint disappeared during capture.',
          );
        }
        if (_sameEvidence(whole, current)) {
          return ObjectHistoryCurrentStateCaptureResult(
            revisionId: latest.entry.revisionId,
            appended: false,
          );
        }
      }

      final previousRevisionId = latest?.entry.revisionId;
      final revisionId = (previousRevisionId ?? 0) + 1;
      final checkpoint = ObjectHistoryCheckpointPayload(
        entry: ObjectHistoryEntry(
          objectId: objectId,
          revisionId: revisionId,
          previousRevisionId: previousRevisionId,
          capturedAt: _clock().toUtc(),
          source: source,
        ),
        title: current.title,
        propertySnapshots: current.propertySnapshots,
        body: current.body,
        relationRequirements: current.relationRequirements,
      );

      final appended = await _coordinator.append(
        checkpoint: checkpoint,
        relationSnapshots: current.relationSnapshots,
      );
      return ObjectHistoryCurrentStateCaptureResult(
        revisionId: revisionId,
        appended: appended,
      );
    });
  }

  Future<_CurrentHistoryEvidence> _readCurrentEvidence({
    required int objectTypeId,
    required int objectId,
  }) async {
    await _genericStore.ensureSchema();

    final objectRow = await _genericStore.database
        .customSelect(
          '''SELECT r.database_id, r.title, d.workspace_id
             FROM generic_records r
             JOIN generic_databases d ON d.id = r.database_id
             WHERE r.id = ?
             LIMIT 1''',
          variables: [Variable<int>(objectId)],
        )
        .getSingleOrNull();
    if (objectRow == null) {
      throw StateError('Cannot capture history for a missing Object.');
    }

    final storedObjectTypeId = objectRow.read<int>('database_id');
    if (storedObjectTypeId != objectTypeId) {
      throw StateError(
        'Object history capture ObjectType does not match current persistence.',
      );
    }
    final title = objectRow.read<String>('title');
    if (title.trim().isEmpty) {
      throw StateError('Cannot capture Object history with an empty title.');
    }
    final workspaceId = objectRow.read<int>('workspace_id');

    final properties = await _readStrictProperties(objectTypeId);
    final propertiesById = <int, ObjectPropertyDefinition>{
      for (final property in properties) property.id: property,
    };
    final values = await _readStrictValues(objectId);
    for (final propertyId in values.keys) {
      final property = propertiesById[propertyId];
      if (property == null) {
        throw StateError(
          'Object history capture found a value for a missing Property.',
        );
      }
      if (property.isComputed) {
        throw StateError(
          'Object history capture found persisted data for a computed Property.',
        );
      }
    }

    final body = await _bodyStore.read(objectId);
    final propertySnapshots = <ObjectHistoryPropertySnapshot>[];
    final relationRequirements = <ObjectHistoryRelationRequirement>[];
    final relationSnapshots = <ObjectHistoryRelationSnapshot>[];

    for (final property in properties) {
      if (property.isRelation) {
        relationRequirements.add(
          ObjectHistoryRelationRequirement.fromDefinition(property),
        );
        relationSnapshots.add(
          await _relationService.capture(
            workspaceId: workspaceId,
            sourceObjectId: objectId,
            propertyId: property.id,
          ),
        );
        continue;
      }
      if (!_isPersistedValueHistoryProperty(property)) continue;
      propertySnapshots.add(
        ObjectHistoryPropertySnapshot.fromDefinition(
          property: property,
          value: values[property.id],
        ),
      );
    }

    propertySnapshots.sort((left, right) => left.propertyId - right.propertyId);
    relationRequirements.sort(
      (left, right) => left.propertyId - right.propertyId,
    );
    relationSnapshots.sort((left, right) => left.propertyId - right.propertyId);

    return _CurrentHistoryEvidence(
      title: title,
      propertySnapshots: propertySnapshots,
      body: body,
      relationRequirements: relationRequirements,
      relationSnapshots: relationSnapshots,
    );
  }

  Future<List<ObjectPropertyDefinition>> _readStrictProperties(
    int objectTypeId,
  ) async {
    final rows = await _genericStore.database
        .customSelect(
          '''SELECT id, database_id, name, type, config_json, sort_order
             FROM generic_properties
             WHERE database_id = ?
             ORDER BY id''',
          variables: [Variable<int>(objectTypeId)],
        )
        .get();

    final properties = <ObjectPropertyDefinition>[];
    for (final row in rows) {
      final id = row.read<int>('id');
      final config = _decodeStrictMap(
        row.read<String>('config_json'),
        'Property $id configuration',
      );
      ObjectPropertyType type;
      try {
        type = ObjectPropertyDefinition.fromStorageType(
          row.read<String>('type'),
        );
      } on FormatException {
        throw StateError(
          'Object history capture found an unsupported Property type.',
        );
      }
      properties.add(
        ObjectPropertyDefinition(
          id: id,
          objectTypeId: row.read<int>('database_id'),
          name: row.read<String>('name'),
          type: type,
          sortOrder: row.read<int>('sort_order'),
          config: config,
        ),
      );
    }
    return properties;
  }

  Future<Map<int, dynamic>> _readStrictValues(int objectId) async {
    final rows = await _genericStore.database
        .customSelect(
          '''SELECT property_id, value_json
             FROM generic_values
             WHERE record_id = ?
             ORDER BY property_id''',
          variables: [Variable<int>(objectId)],
        )
        .get();
    final values = <int, dynamic>{};
    for (final row in rows) {
      final propertyId = row.read<int>('property_id');
      try {
        values[propertyId] = jsonDecode(row.read<String>('value_json'));
      } on FormatException {
        throw StateError(
          'Object history capture found malformed persisted Property value JSON.',
        );
      }
    }
    return values;
  }
}

class _CurrentHistoryEvidence {
  _CurrentHistoryEvidence({
    required this.title,
    required List<ObjectHistoryPropertySnapshot> propertySnapshots,
    required this.body,
    required List<ObjectHistoryRelationRequirement> relationRequirements,
    required List<ObjectHistoryRelationSnapshot> relationSnapshots,
  }) : propertySnapshots = List<ObjectHistoryPropertySnapshot>.unmodifiable(
         propertySnapshots,
       ),
       relationRequirements =
           List<ObjectHistoryRelationRequirement>.unmodifiable(
             relationRequirements,
           ),
       relationSnapshots = List<ObjectHistoryRelationSnapshot>.unmodifiable(
         relationSnapshots,
       );

  final String title;
  final List<ObjectHistoryPropertySnapshot> propertySnapshots;
  final ObjectBodyDocument body;
  final List<ObjectHistoryRelationRequirement> relationRequirements;
  final List<ObjectHistoryRelationSnapshot> relationSnapshots;
}

bool _sameEvidence(
  ObjectHistoryWholeCheckpoint historical,
  _CurrentHistoryEvidence current,
) {
  final checkpoint = historical.checkpoint;
  if (checkpoint.title != current.title) return false;
  if (!_samePropertySnapshots(
    checkpoint.propertySnapshots,
    current.propertySnapshots,
  )) {
    return false;
  }
  if (_canonicalJson(checkpoint.body.toJson()) !=
      _canonicalJson(current.body.toJson())) {
    return false;
  }
  final historicalRelationIds =
      checkpoint.relationRequirements.map((item) => item.propertyId).toList()
        ..sort();
  final currentRelationIds =
      current.relationRequirements.map((item) => item.propertyId).toList()
        ..sort();
  if (!_sameIntList(historicalRelationIds, currentRelationIds)) return false;

  final historicalRelations = [...historical.relationSnapshots]
    ..sort((left, right) => left.propertyId - right.propertyId);
  final currentRelations = [...current.relationSnapshots]
    ..sort((left, right) => left.propertyId - right.propertyId);
  if (historicalRelations.length != currentRelations.length) return false;
  for (var index = 0; index < historicalRelations.length; index += 1) {
    if (_canonicalJson(historicalRelations[index].toJson()) !=
        _canonicalJson(currentRelations[index].toJson())) {
      return false;
    }
  }
  return true;
}

bool _samePropertySnapshots(
  List<ObjectHistoryPropertySnapshot> left,
  List<ObjectHistoryPropertySnapshot> right,
) {
  if (left.length != right.length) return false;
  final sortedLeft = [...left]..sort((a, b) => a.propertyId - b.propertyId);
  final sortedRight = [...right]..sort((a, b) => a.propertyId - b.propertyId);
  for (var index = 0; index < sortedLeft.length; index += 1) {
    final a = sortedLeft[index];
    final b = sortedRight[index];
    if (a.propertyId != b.propertyId || a.type != b.type) return false;
    if (_canonicalJson(a.value) != _canonicalJson(b.value)) return false;
  }
  return true;
}

bool _sameIntList(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String _canonicalJson(dynamic value) => jsonEncode(_canonicalize(value));

dynamic _canonicalize(dynamic value) {
  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }
  if (value is Map) {
    final keys = value.keys.map((key) {
      if (key is! String) {
        throw const FormatException(
          'Object history evidence map keys must be strings.',
        );
      }
      return key;
    }).toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  return value;
}

Map<String, dynamic> _decodeStrictMap(String raw, String label) {
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    throw StateError('$label is malformed.');
  }
  if (decoded is! Map) {
    throw StateError('$label must be a JSON object.');
  }
  try {
    return Map<String, dynamic>.from(decoded);
  } on TypeError {
    throw StateError('$label must use string JSON keys.');
  }
}

bool _isPersistedValueHistoryProperty(ObjectPropertyDefinition property) =>
    property.isValue &&
    property.type != ObjectPropertyType.title &&
    property.type != ObjectPropertyType.createdTime &&
    property.type != ObjectPropertyType.updatedTime;

void _validatePositiveId(int value, String name) {
  if (value <= 0) {
    throw ArgumentError.value(value, name, '$name must be positive.');
  }
}
