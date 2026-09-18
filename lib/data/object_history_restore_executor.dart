import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/object_history_checkpoint.dart';
import '../domain/object_history_contract.dart';
import '../domain/object_history_relation.dart';
import '../domain/object_history_restore_composition.dart';
import '../domain/object_history_restore_planner.dart';
import '../domain/object_model.dart';
import 'generic_database_store.dart';
import 'object_body_store.dart';
import 'object_history_relation_service.dart';
import 'object_history_restore_preparation_service.dart';

typedef ObjectHistoryCurrentCheckpointLoad =
    Future<ObjectHistoryCheckpointPayload> Function();

typedef ObjectHistoryRelationRestoreApply =
    Future<ObjectHistoryRelationRestoreImpact> Function(
      ObjectHistoryRelationRestorePlan plan,
    );

class ObjectHistoryRestoreImpact {
  ObjectHistoryRestoreImpact({
    required this.objectId,
    required Iterable<int> changedObjectIds,
  }) : changedObjectIds = List<int>.unmodifiable(
         (<int>{objectId, ...changedObjectIds}.toList()..sort()),
       );

  final int objectId;
  final List<int> changedObjectIds;
}

/// A-owned execution boundary for an already-prepared durable history restore.
///
/// The preparation remains read-only evidence. Execution rechecks the current
/// revision inside one database transaction, applies only A-owned title/value
/// Property/Body decisions, and delegates every Relation mutation to B's
/// canonical history restore service. Any late A/B failure therefore rolls the
/// whole restore back without mutating immutable historical evidence.
class ObjectHistoryRestoreExecutor {
  ObjectHistoryRestoreExecutor({
    required GenericDatabaseStore genericStore,
    required ObjectHistoryCurrentCheckpointLoad loadCurrent,
    required ObjectHistoryRelationRestoreApply applyRelationRestore,
    ObjectBodyStore? bodyStore,
  }) : _genericStore = genericStore,
       _loadCurrent = loadCurrent,
       _applyRelationRestore = applyRelationRestore,
       _bodyStore = bodyStore ?? ObjectBodyStore(genericStore);

  factory ObjectHistoryRestoreExecutor.fromServices({
    required GenericDatabaseStore genericStore,
    required ObjectHistoryCurrentCheckpointLoad loadCurrent,
    required ObjectHistoryRelationService relationService,
  }) => ObjectHistoryRestoreExecutor(
    genericStore: genericStore,
    loadCurrent: loadCurrent,
    applyRelationRestore: relationService.applyRestore,
  );

  final GenericDatabaseStore _genericStore;
  final ObjectHistoryCurrentCheckpointLoad _loadCurrent;
  final ObjectHistoryRelationRestoreApply _applyRelationRestore;
  final ObjectBodyStore _bodyStore;

  Future<ObjectHistoryRestoreImpact> execute({
    required ObjectHistoryRestorePreparation preparation,
    required int expectedCurrentRevisionId,
  }) async {
    if (!preparation.canCoordinate) {
      throw StateError(
        'Blocked history restore preparation cannot be executed.',
      );
    }
    if (expectedCurrentRevisionId <= 0) {
      throw ArgumentError.value(
        expectedCurrentRevisionId,
        'expectedCurrentRevisionId',
        'Expected current history revision must be positive.',
      );
    }
    if (expectedCurrentRevisionId !=
        preparation.preview.preparedCurrentRevisionId) {
      throw StateError(
        'Restore execution revision does not match the prepared current revision.',
      );
    }

    return _genericStore.database.transaction(() async {
      final current = await _loadCurrent();
      if (current.entry.objectId != preparation.preview.objectId) {
        throw StateError('Current checkpoint belongs to a different Object.');
      }

      final executionPlan = preparation.preview.coordinateWithRelations(
        actualCurrentRevisionId: current.entry.revisionId,
        relationPlans: preparation.relationPlans,
      );
      if (!executionPlan.isExecutable ||
          current.entry.revisionId != expectedCurrentRevisionId) {
        throw StateError(
          'History restore preparation is stale; prepare again before executing.',
        );
      }

      // Re-run the A-owned comparison against the state read inside this
      // transaction. This catches Property/type/Body drift even if a caller
      // accidentally reused a logical revision id.
      final freshPreview = const ObjectHistoryCheckpointRestorePlanner()
          .preview(
            historical: preparation.historical.checkpoint,
            current: current,
            scope: preparation.preview.scope,
          );
      if (freshPreview.hasAOwnedBlockers ||
          freshPreview.preparedCurrentRevisionId != expectedCurrentRevisionId ||
          !_sameDecisions(
            preparation.preview.decisions,
            freshPreview.decisions,
          )) {
        throw StateError(
          'Current Object state no longer matches the prepared history restore.',
        );
      }

      final historical = preparation.historical.checkpoint;
      final historicalValues = <int, ObjectHistoryPropertySnapshot>{
        for (final snapshot in historical.propertySnapshots)
          snapshot.propertyId: snapshot,
      };
      final currentValues = <int, ObjectHistoryPropertySnapshot>{
        for (final snapshot in current.propertySnapshots)
          snapshot.propertyId: snapshot,
      };

      // Identity-managed Values are historical evidence, but their owning
      // lifecycle service remains the only mutation authority. Preflight every
      // requested Value restore before any A/B mutation so GenericDatabaseStore
      // cannot silently no-op a changed identity fact and report success.
      final objectTypeId = await _objectTypeId(historical.entry.objectId);
      for (final decision in freshPreview.decisions) {
        if (!decision.needsRestore ||
            decision.target.kind != ObjectHistoryFieldKind.property) {
          continue;
        }
        final propertyId = decision.target.propertyId!;
        final config = await _strictPropertyConfig(
          objectTypeId: objectTypeId,
          propertyId: propertyId,
        );
        if (ObjectPropertyDefinition.isIdentityManagedConfig(config)) {
          throw StateError(
            'Identity-managed Value Property $propertyId cannot be changed by generic history restore.',
          );
        }
      }

      for (final decision in freshPreview.decisions) {
        if (!decision.needsRestore) continue;
        switch (decision.target.kind) {
          case ObjectHistoryFieldKind.title:
            await _genericStore.renameRecord(
              historical.entry.objectId,
              historical.title,
            );
          case ObjectHistoryFieldKind.property:
            final propertyId = decision.target.propertyId!;
            final historicalValue = historicalValues[propertyId];
            final currentValue = currentValues[propertyId];
            if (historicalValue == null ||
                currentValue == null ||
                historicalValue.type != currentValue.type) {
              throw StateError(
                'Value Property $propertyId changed during history restore execution.',
              );
            }
            await _genericStore.setValue(
              recordId: historical.entry.objectId,
              propertyId: propertyId,
              value: historicalValue.value,
            );
          case ObjectHistoryFieldKind.body:
            final changed = await _bodyStore.writeIfUnchanged(
              objectId: historical.entry.objectId,
              expected: current.body,
              document: historical.body,
            );
            if (!changed) {
              throw StateError(
                'Object Body changed during history restore execution.',
              );
            }
        }
      }

      final changedObjectIds = <int>{historical.entry.objectId};
      for (final relationPlan in executionPlan.relationPlans) {
        final impact = await _applyRelationRestore(relationPlan);
        changedObjectIds.addAll(impact.changedObjectIds);
      }

      return ObjectHistoryRestoreImpact(
        objectId: historical.entry.objectId,
        changedObjectIds: changedObjectIds,
      );
    });
  }

  Future<Map<String, dynamic>> _strictPropertyConfig({
    required int objectTypeId,
    required int propertyId,
  }) async {
    final row = await _genericStore.database
        .customSelect(
          '''SELECT config_json
             FROM generic_properties
             WHERE id = ? AND database_id = ?
             LIMIT 1''',
          variables: [Variable<int>(propertyId), Variable<int>(objectTypeId)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw StateError(
        'Value Property $propertyId is missing during history restore execution.',
      );
    }

    final raw = row.read<String>('config_json');
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw StateError(
        'Value Property $propertyId has malformed configuration during history restore execution.',
      );
    }
    if (decoded is! Map) {
      throw StateError(
        'Value Property $propertyId has malformed configuration during history restore execution.',
      );
    }
    try {
      return Map<String, dynamic>.from(decoded);
    } on TypeError {
      throw StateError(
        'Value Property $propertyId has malformed configuration during history restore execution.',
      );
    }
  }

  Future<int> _objectTypeId(int objectId) async {
    final row = await _genericStore.database
        .customSelect(
          'SELECT database_id FROM generic_records WHERE id = ? LIMIT 1',
          variables: [Variable<int>(objectId)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw StateError(
        'Current Object is missing during history restore execution.',
      );
    }
    return row.read<int>('database_id');
  }
}

bool _sameDecisions(
  List<ObjectHistoryRestoreFieldDecision> left,
  List<ObjectHistoryRestoreFieldDecision> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    final a = left[index];
    final b = right[index];
    if (a.target.key != b.target.key || a.kind != b.kind) return false;
  }
  return true;
}
