import 'managed_file_ownership.dart';
import 'object_history_contract.dart';

/// Stable Storage-owned identity for one app-managed byte location.
///
/// The identity is intentionally Vault-relative so Vault move/backup/restore can
/// preserve it. Explicit [ownership] is required separately; a path living under
/// a Vault never manufactures managed-byte ownership by itself.
class ManagedByteIdentity {
  ManagedByteIdentity({
    required this.ownership,
    required String vaultRelativePath,
  }) : vaultRelativePath = _validateVaultRelativePath(vaultRelativePath);

  final ManagedFileOwnership ownership;
  final String vaultRelativePath;

  String get key => '${ownership.storageKey}:$vaultRelativePath';

  @override
  bool operator ==(Object other) =>
      other is ManagedByteIdentity &&
      other.ownership == ownership &&
      other.vaultRelativePath == vaultRelativePath;

  @override
  int get hashCode => Object.hash(ownership, vaultRelativePath);
}

/// Storage-owned identity for one durable-history checkpoint retention claim.
///
/// A revision id is scoped to its Object. It is never safe to key byte retention
/// by [revisionId] alone because two Objects can independently have the same
/// revision number. This mirrors A's durable checkpoint identity without taking
/// ownership of A's checkpoint semantics.
class ManagedByteHistoryCheckpointIdentity {
  ManagedByteHistoryCheckpointIdentity({
    required this.objectId,
    required this.revisionId,
  }) {
    if (objectId <= 0) {
      throw ArgumentError.value(
        objectId,
        'objectId',
        'History checkpoint Object ids must be positive.',
      );
    }
    if (revisionId <= 0) {
      throw ArgumentError.value(
        revisionId,
        'revisionId',
        'History checkpoint revision ids must be positive.',
      );
    }
  }

  factory ManagedByteHistoryCheckpointIdentity.fromEntry(
    ObjectHistoryEntry entry,
  ) => ManagedByteHistoryCheckpointIdentity(
    objectId: entry.objectId,
    revisionId: entry.revisionId,
  );

  final int objectId;
  final int revisionId;

  String get key => 'object:$objectId/revision:$revisionId';

  @override
  bool operator ==(Object other) =>
      other is ManagedByteHistoryCheckpointIdentity &&
      other.objectId == objectId &&
      other.revisionId == revisionId;

  @override
  int get hashCode => Object.hash(objectId, revisionId);
}

enum HistoryByteReferenceKind { managed, external }

/// Logical file reference captured by durable history.
///
/// External references stay external and never become app-owned retention or
/// deletion candidates. Managed references require an independently supplied
/// [ManagedByteIdentity], which already carries explicit ownership provenance.
class HistoryByteReference {
  HistoryByteReference.managed(ManagedByteIdentity identity)
    : kind = HistoryByteReferenceKind.managed,
      managedIdentity = identity,
      storedReference = identity.vaultRelativePath;

  HistoryByteReference.external(String absolutePath)
    : kind = HistoryByteReferenceKind.external,
      managedIdentity = null,
      storedReference = _validateExternalAbsolutePath(absolutePath);

  final HistoryByteReferenceKind kind;
  final ManagedByteIdentity? managedIdentity;
  final String storedReference;
}

enum HistoryManagedByteRestoreability { metadataOnly, retainedRestorable }

enum ManagedByteGcBlocker {
  currentReference,
  retainedHistory,
  preservationClaim,
  incompleteReferenceAudit,
}

/// Result of the pure retention-policy audit before any filesystem deletion.
///
/// [eligibleForPhysicalDeletion] is only a policy precondition. The canonical
/// filesystem deletion boundary must still verify Object absence, ownership,
/// alias/path safety, and actual shared references immediately before deleting.
class ManagedByteGcDecision {
  ManagedByteGcDecision._(Set<ManagedByteGcBlocker> blockers)
    : blockers = Set<ManagedByteGcBlocker>.unmodifiable(blockers);

  final Set<ManagedByteGcBlocker> blockers;

  bool get eligibleForPhysicalDeletion => blockers.isEmpty;
}

/// Immutable claim state for one managed byte.
///
/// Claim ids are opaque to this contract. Current-state references, retained
/// historical checkpoints, and backup/export preservation requirements remain
/// separate so releasing one claim never implies immediate physical deletion.
class ManagedByteRetentionState {
  ManagedByteRetentionState({
    required this.identity,
    Iterable<String> currentReferenceKeys = const <String>[],
    Iterable<ManagedByteHistoryCheckpointIdentity> retainedHistoryCheckpoints =
        const <ManagedByteHistoryCheckpointIdentity>[],
    Iterable<String> preservationClaimKeys = const <String>[],
    required this.referenceAuditComplete,
  }) : currentReferenceKeys = Set<String>.unmodifiable(
         _normalizeClaimKeys(currentReferenceKeys, 'currentReferenceKeys'),
       ),
       retainedHistoryCheckpoints =
           Set<ManagedByteHistoryCheckpointIdentity>.unmodifiable(
             _validateHistoryCheckpointIdentities(retainedHistoryCheckpoints),
           ),
       preservationClaimKeys = Set<String>.unmodifiable(
         _normalizeClaimKeys(preservationClaimKeys, 'preservationClaimKeys'),
       );

  final ManagedByteIdentity identity;
  final Set<String> currentReferenceKeys;
  final Set<ManagedByteHistoryCheckpointIdentity> retainedHistoryCheckpoints;
  final Set<String> preservationClaimKeys;

  /// True only when the caller has completely audited all Storage-relevant
  /// reference sources required before physical deletion can even be considered.
  final bool referenceAuditComplete;

  ManagedByteGcDecision evaluateGc() {
    final blockers = <ManagedByteGcBlocker>{};
    if (currentReferenceKeys.isNotEmpty) {
      blockers.add(ManagedByteGcBlocker.currentReference);
    }
    if (retainedHistoryCheckpoints.isNotEmpty) {
      blockers.add(ManagedByteGcBlocker.retainedHistory);
    }
    if (preservationClaimKeys.isNotEmpty) {
      blockers.add(ManagedByteGcBlocker.preservationClaim);
    }
    if (!referenceAuditComplete) {
      blockers.add(ManagedByteGcBlocker.incompleteReferenceAudit);
    }
    return ManagedByteGcDecision._(blockers);
  }

  HistoryManagedByteRestoreability restoreabilityFor({
    required HistoryByteReference reference,
    required ManagedByteHistoryCheckpointIdentity checkpoint,
    required bool managedByteVerifiedPresent,
  }) {
    if (reference.kind == HistoryByteReferenceKind.external) {
      return HistoryManagedByteRestoreability.metadataOnly;
    }
    if (reference.managedIdentity != identity) {
      throw ArgumentError(
        'History managed-byte reference does not match this retention state.',
      );
    }
    if (!retainedHistoryCheckpoints.contains(checkpoint) ||
        !managedByteVerifiedPresent) {
      return HistoryManagedByteRestoreability.metadataOnly;
    }
    return HistoryManagedByteRestoreability.retainedRestorable;
  }

  ManagedByteRetentionState retainCurrentReference(String claimKey) =>
      _copyWith(
        currentReferenceKeys: <String>{
          ...currentReferenceKeys,
          _claimKey(claimKey),
        },
      );

  ManagedByteRetentionState releaseCurrentReference(String claimKey) =>
      _copyWith(
        currentReferenceKeys: <String>{
          ...currentReferenceKeys.where((key) => key != _claimKey(claimKey)),
        },
      );

  ManagedByteRetentionState retainHistoryCheckpoint(
    ManagedByteHistoryCheckpointIdentity checkpoint,
  ) => _copyWith(
    retainedHistoryCheckpoints: <ManagedByteHistoryCheckpointIdentity>{
      ...retainedHistoryCheckpoints,
      checkpoint,
    },
  );

  ManagedByteRetentionState releaseHistoryCheckpoint(
    ManagedByteHistoryCheckpointIdentity checkpoint,
  ) => _copyWith(
    retainedHistoryCheckpoints: <ManagedByteHistoryCheckpointIdentity>{
      ...retainedHistoryCheckpoints.where((claim) => claim != checkpoint),
    },
  );

  /// Releases the byte claim associated with a checkpoint that A has already
  /// selected for bounded-history compaction.
  ///
  /// F does not choose which checkpoints A compacts. `keepAll` cannot release a
  /// retention claim through compaction; bounded policy may release the selected
  /// claim, after which [evaluateGc] still requires all other claims and the
  /// complete reference audit to be clear before deletion can be considered.
  ManagedByteRetentionState releaseHistoryCheckpointForCompaction({
    required ManagedByteHistoryCheckpointIdentity checkpoint,
    required ObjectHistoryRetentionPolicy policy,
  }) {
    if (policy.kind == ObjectHistoryRetentionKind.keepAll) {
      throw StateError(
        'keepAll history retention cannot release managed-byte claims by compaction.',
      );
    }
    return releaseHistoryCheckpoint(checkpoint);
  }

  ManagedByteRetentionState retainPreservationClaim(String claimKey) =>
      _copyWith(
        preservationClaimKeys: <String>{
          ...preservationClaimKeys,
          _claimKey(claimKey),
        },
      );

  ManagedByteRetentionState releasePreservationClaim(String claimKey) =>
      _copyWith(
        preservationClaimKeys: <String>{
          ...preservationClaimKeys.where((key) => key != _claimKey(claimKey)),
        },
      );

  ManagedByteRetentionState withReferenceAuditComplete(bool complete) =>
      _copyWith(referenceAuditComplete: complete);

  ManagedByteRetentionState _copyWith({
    Set<String>? currentReferenceKeys,
    Set<ManagedByteHistoryCheckpointIdentity>? retainedHistoryCheckpoints,
    Set<String>? preservationClaimKeys,
    bool? referenceAuditComplete,
  }) => ManagedByteRetentionState(
    identity: identity,
    currentReferenceKeys: currentReferenceKeys ?? this.currentReferenceKeys,
    retainedHistoryCheckpoints:
        retainedHistoryCheckpoints ?? this.retainedHistoryCheckpoints,
    preservationClaimKeys: preservationClaimKeys ?? this.preservationClaimKeys,
    referenceAuditComplete:
        referenceAuditComplete ?? this.referenceAuditComplete,
  );
}

String _validateVaultRelativePath(String value) {
  final path = value.trim();
  if (path.isEmpty || path != value) {
    throw ArgumentError.value(
      value,
      'vaultRelativePath',
      'Managed byte paths must be non-empty and normalized.',
    );
  }
  if (path.contains('\\') || path.startsWith('/') || _isDriveQualified(path)) {
    throw ArgumentError.value(
      value,
      'vaultRelativePath',
      'Managed byte identity requires a Vault-relative forward-slash path.',
    );
  }
  final segments = path.split('/');
  if (segments.any(
    (segment) => segment.isEmpty || segment == '.' || segment == '..',
  )) {
    throw ArgumentError.value(
      value,
      'vaultRelativePath',
      'Managed byte paths cannot contain empty, dot, or traversal segments.',
    );
  }
  return path;
}

String _validateExternalAbsolutePath(String value) {
  final path = value.trim();
  if (path.isEmpty || path != value || !_isAbsolutePath(path)) {
    throw ArgumentError.value(
      value,
      'absolutePath',
      'External history file references must remain explicit absolute paths.',
    );
  }
  return path;
}

bool _isAbsolutePath(String value) =>
    value.startsWith('/') ||
    value.startsWith(r'\\') ||
    RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);

bool _isDriveQualified(String value) => RegExp(r'^[A-Za-z]:').hasMatch(value);

Set<String> _normalizeClaimKeys(Iterable<String> values, String parameterName) {
  final result = <String>{};
  for (final value in values) {
    final normalized = _claimKey(value, parameterName: parameterName);
    if (!result.add(normalized)) {
      throw ArgumentError.value(
        value,
        parameterName,
        'Managed-byte claim keys must be unique.',
      );
    }
  }
  return result;
}

String _claimKey(String value, {String parameterName = 'claimKey'}) {
  final key = value.trim();
  if (key.isEmpty || key != value) {
    throw ArgumentError.value(
      value,
      parameterName,
      'Managed-byte claim keys must be non-empty and normalized.',
    );
  }
  return key;
}

Set<ManagedByteHistoryCheckpointIdentity> _validateHistoryCheckpointIdentities(
  Iterable<ManagedByteHistoryCheckpointIdentity> values,
) {
  final result = <ManagedByteHistoryCheckpointIdentity>{};
  for (final value in values) {
    if (!result.add(value)) {
      throw ArgumentError.value(
        value.key,
        'retainedHistoryCheckpoints',
        'Managed-byte history checkpoint claims must be unique.',
      );
    }
  }
  return result;
}
