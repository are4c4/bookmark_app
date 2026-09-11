import 'package:bookmark_app/domain/managed_byte_retention_contract.dart';
import 'package:bookmark_app/domain/managed_file_ownership.dart';
import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ManagedByteIdentity managedIdentity() => ManagedByteIdentity(
    ownership: ManagedFileOwnership.vaultManagedCopy,
    vaultRelativePath: 'photos/history/image.png',
  );

  ManagedByteHistoryCheckpointIdentity checkpoint(
    int objectId,
    int revisionId,
  ) => ManagedByteHistoryCheckpointIdentity(
    objectId: objectId,
    revisionId: revisionId,
  );

  group('ManagedByteIdentity', () {
    test('is Vault-relative and stable across Vault location changes', () {
      final identity = managedIdentity();

      expect(identity.vaultRelativePath, 'photos/history/image.png');
      expect(identity.key, 'vault-managed-copy-v1:photos/history/image.png');
      expect(
        identity,
        ManagedByteIdentity(
          ownership: ManagedFileOwnership.vaultManagedCopy,
          vaultRelativePath: 'photos/history/image.png',
        ),
      );
    });

    test('rejects absolute, traversal, and backslash managed paths', () {
      for (final path in <String>[
        '/tmp/image.png',
        'C:/tmp/image.png',
        r'photos\image.png',
        'photos/../image.png',
        'photos//image.png',
        './photos/image.png',
      ]) {
        expect(
          () => ManagedByteIdentity(
            ownership: ManagedFileOwnership.vaultManagedCopy,
            vaultRelativePath: path,
          ),
          throwsArgumentError,
          reason: path,
        );
      }
    });
  });

  group('ManagedByteHistoryCheckpointIdentity', () {
    test('keeps Object-scoped revision identities distinct', () {
      expect(checkpoint(10, 4), isNot(checkpoint(11, 4)));
      expect(checkpoint(10, 4), checkpoint(10, 4));
      expect(checkpoint(10, 4).key, 'object:10/revision:4');
    });

    test('can mirror A-owned durable checkpoint identity', () {
      final entry = ObjectHistoryEntry(
        objectId: 42,
        revisionId: 7,
        capturedAt: DateTime.utc(2026, 9, 11),
        source: ObjectHistorySourceKind.userMutation,
      );

      expect(
        ManagedByteHistoryCheckpointIdentity.fromEntry(entry),
        checkpoint(42, 7),
      );
    });

    test('rejects non-positive Object or revision ids', () {
      expect(() => checkpoint(0, 1), throwsArgumentError);
      expect(() => checkpoint(1, 0), throwsArgumentError);
    });
  });

  group('HistoryByteReference', () {
    test('external absolute references remain metadata-only', () {
      final state = ManagedByteRetentionState(
        identity: managedIdentity(),
        retainedHistoryCheckpoints: <ManagedByteHistoryCheckpointIdentity>[
          checkpoint(10, 4),
        ],
        referenceAuditComplete: true,
      );
      final external = HistoryByteReference.external('/external/photo.png');

      expect(external.kind, HistoryByteReferenceKind.external);
      expect(external.managedIdentity, isNull);
      expect(
        state.restoreabilityFor(
          reference: external,
          checkpoint: checkpoint(10, 4),
          managedByteVerifiedPresent: true,
        ),
        HistoryManagedByteRestoreability.metadataOnly,
      );
    });

    test('external references must stay explicit absolute paths', () {
      expect(
        () => HistoryByteReference.external('photos/image.png'),
        throwsArgumentError,
      );
      expect(
        () => HistoryByteReference.external(r'C:relative\image.png'),
        throwsArgumentError,
      );
      expect(
        HistoryByteReference.external(r'C:\outside\image.png').storedReference,
        r'C:\outside\image.png',
      );
    });
  });

  group('ManagedByteRetentionState GC safety', () {
    test(
      'one released history claim cannot delete a multiply referenced byte',
      () {
        var state = ManagedByteRetentionState(
          identity: managedIdentity(),
          currentReferenceKeys: const <String>['object:10/property:3'],
          retainedHistoryCheckpoints: <ManagedByteHistoryCheckpointIdentity>[
            checkpoint(10, 4),
            checkpoint(10, 5),
          ],
          referenceAuditComplete: true,
        );

        state = state.releaseHistoryCheckpoint(checkpoint(10, 4));
        var decision = state.evaluateGc();
        expect(decision.eligibleForPhysicalDeletion, isFalse);
        expect(
          decision.blockers,
          containsAll(<ManagedByteGcBlocker>[
            ManagedByteGcBlocker.currentReference,
            ManagedByteGcBlocker.retainedHistory,
          ]),
        );

        state = state.releaseCurrentReference('object:10/property:3');
        decision = state.evaluateGc();
        expect(decision.eligibleForPhysicalDeletion, isFalse);
        expect(decision.blockers, <ManagedByteGcBlocker>{
          ManagedByteGcBlocker.retainedHistory,
        });

        state = state.releaseHistoryCheckpoint(checkpoint(10, 5));
        expect(state.evaluateGc().eligibleForPhysicalDeletion, isTrue);
      },
    );

    test('same revision number on different Objects remains independent', () {
      final objectA = checkpoint(10, 4);
      final objectB = checkpoint(20, 4);
      final reference = HistoryByteReference.managed(managedIdentity());
      var state = ManagedByteRetentionState(
        identity: managedIdentity(),
        retainedHistoryCheckpoints: <ManagedByteHistoryCheckpointIdentity>[
          objectA,
          objectB,
        ],
        referenceAuditComplete: true,
      );

      state = state.releaseHistoryCheckpoint(objectA);

      expect(
        state.retainedHistoryCheckpoints,
        <ManagedByteHistoryCheckpointIdentity>{objectB},
      );
      expect(state.evaluateGc().eligibleForPhysicalDeletion, isFalse);
      expect(state.evaluateGc().blockers, <ManagedByteGcBlocker>{
        ManagedByteGcBlocker.retainedHistory,
      });
      expect(
        state.restoreabilityFor(
          reference: reference,
          checkpoint: objectA,
          managedByteVerifiedPresent: true,
        ),
        HistoryManagedByteRestoreability.metadataOnly,
      );
      expect(
        state.restoreabilityFor(
          reference: reference,
          checkpoint: objectB,
          managedByteVerifiedPresent: true,
        ),
        HistoryManagedByteRestoreability.retainedRestorable,
      );
    });

    test(
      'preservation claim blocks GC after current/history claims are gone',
      () {
        var state = ManagedByteRetentionState(
          identity: managedIdentity(),
          preservationClaimKeys: const <String>['backup:latest'],
          referenceAuditComplete: true,
        );

        expect(state.evaluateGc().eligibleForPhysicalDeletion, isFalse);
        expect(state.evaluateGc().blockers, <ManagedByteGcBlocker>{
          ManagedByteGcBlocker.preservationClaim,
        });

        state = state.releasePreservationClaim('backup:latest');
        expect(state.evaluateGc().eligibleForPhysicalDeletion, isTrue);
      },
    );

    test('ambiguity retains bytes even when no explicit claims remain', () {
      final state = ManagedByteRetentionState(
        identity: managedIdentity(),
        referenceAuditComplete: false,
      );

      expect(state.evaluateGc().eligibleForPhysicalDeletion, isFalse);
      expect(state.evaluateGc().blockers, <ManagedByteGcBlocker>{
        ManagedByteGcBlocker.incompleteReferenceAudit,
      });
      expect(
        state
            .withReferenceAuditComplete(true)
            .evaluateGc()
            .eligibleForPhysicalDeletion,
        isTrue,
      );
    });
  });

  group('history retention policy interaction', () {
    test('bounded compaction releases only the selected checkpoint claim', () {
      final checkpoint8 = checkpoint(10, 8);
      final checkpoint9 = checkpoint(10, 9);
      final state = ManagedByteRetentionState(
        identity: managedIdentity(),
        retainedHistoryCheckpoints: <ManagedByteHistoryCheckpointIdentity>[
          checkpoint8,
          checkpoint9,
        ],
        referenceAuditComplete: true,
      );

      final compacted = state.releaseHistoryCheckpointForCompaction(
        checkpoint: checkpoint8,
        policy: ObjectHistoryRetentionPolicy.bounded(maxCheckpoints: 1),
      );

      expect(
        compacted.retainedHistoryCheckpoints,
        <ManagedByteHistoryCheckpointIdentity>{checkpoint9},
      );
      expect(compacted.evaluateGc().eligibleForPhysicalDeletion, isFalse);
    });

    test('keepAll cannot release byte claims through compaction', () {
      final retained = checkpoint(10, 8);
      final state = ManagedByteRetentionState(
        identity: managedIdentity(),
        retainedHistoryCheckpoints: <ManagedByteHistoryCheckpointIdentity>[
          retained,
        ],
        referenceAuditComplete: true,
      );

      expect(
        () => state.releaseHistoryCheckpointForCompaction(
          checkpoint: retained,
          policy: ObjectHistoryRetentionPolicy.keepAll(),
        ),
        throwsStateError,
      );
      expect(
        state.retainedHistoryCheckpoints,
        <ManagedByteHistoryCheckpointIdentity>{retained},
      );
    });
  });

  group('historical restoreability', () {
    test('requires both a retained claim and verified managed bytes', () {
      final identity = managedIdentity();
      final reference = HistoryByteReference.managed(identity);
      final retained = checkpoint(10, 12);
      final state = ManagedByteRetentionState(
        identity: identity,
        retainedHistoryCheckpoints: <ManagedByteHistoryCheckpointIdentity>[
          retained,
        ],
        referenceAuditComplete: true,
      );

      expect(
        state.restoreabilityFor(
          reference: reference,
          checkpoint: retained,
          managedByteVerifiedPresent: false,
        ),
        HistoryManagedByteRestoreability.metadataOnly,
      );
      expect(
        state.restoreabilityFor(
          reference: reference,
          checkpoint: checkpoint(10, 11),
          managedByteVerifiedPresent: true,
        ),
        HistoryManagedByteRestoreability.metadataOnly,
      );
      expect(
        state.restoreabilityFor(
          reference: reference,
          checkpoint: retained,
          managedByteVerifiedPresent: true,
        ),
        HistoryManagedByteRestoreability.retainedRestorable,
      );
    });

    test('managed reference cannot borrow another byte identity retention', () {
      final state = ManagedByteRetentionState(
        identity: managedIdentity(),
        retainedHistoryCheckpoints: <ManagedByteHistoryCheckpointIdentity>[
          checkpoint(10, 12),
        ],
        referenceAuditComplete: true,
      );
      final other = HistoryByteReference.managed(
        ManagedByteIdentity(
          ownership: ManagedFileOwnership.vaultManagedCopy,
          vaultRelativePath: 'attachments/history/document.pdf',
        ),
      );

      expect(
        () => state.restoreabilityFor(
          reference: other,
          checkpoint: checkpoint(10, 12),
          managedByteVerifiedPresent: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
