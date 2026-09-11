import 'package:bookmark_app/domain/managed_byte_retention_contract.dart';
import 'package:bookmark_app/domain/managed_file_ownership.dart';
import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ManagedByteIdentity managedIdentity() => ManagedByteIdentity(
    ownership: ManagedFileOwnership.vaultManagedCopy,
    vaultRelativePath: 'photos/history/image.png',
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

  group('HistoryByteReference', () {
    test('external absolute references remain metadata-only', () {
      final state = ManagedByteRetentionState(
        identity: managedIdentity(),
        retainedHistoryRevisionIds: const <int>[4],
        referenceAuditComplete: true,
      );
      final external = HistoryByteReference.external('/external/photo.png');

      expect(external.kind, HistoryByteReferenceKind.external);
      expect(external.managedIdentity, isNull);
      expect(
        state.restoreabilityFor(
          reference: external,
          revisionId: 4,
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
          retainedHistoryRevisionIds: const <int>[4, 5],
          referenceAuditComplete: true,
        );

        state = state.releaseHistoryRevision(4);
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

        state = state.releaseHistoryRevision(5);
        expect(state.evaluateGc().eligibleForPhysicalDeletion, isTrue);
      },
    );

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
      final state = ManagedByteRetentionState(
        identity: managedIdentity(),
        retainedHistoryRevisionIds: const <int>[8, 9],
        referenceAuditComplete: true,
      );

      final compacted = state.releaseHistoryRevisionForCompaction(
        revisionId: 8,
        policy: ObjectHistoryRetentionPolicy.bounded(maxCheckpoints: 1),
      );

      expect(compacted.retainedHistoryRevisionIds, <int>{9});
      expect(compacted.evaluateGc().eligibleForPhysicalDeletion, isFalse);
    });

    test('keepAll cannot release byte claims through compaction', () {
      final state = ManagedByteRetentionState(
        identity: managedIdentity(),
        retainedHistoryRevisionIds: const <int>[8],
        referenceAuditComplete: true,
      );

      expect(
        () => state.releaseHistoryRevisionForCompaction(
          revisionId: 8,
          policy: ObjectHistoryRetentionPolicy.keepAll(),
        ),
        throwsStateError,
      );
      expect(state.retainedHistoryRevisionIds, <int>{8});
    });
  });

  group('historical restoreability', () {
    test('requires both a retained claim and verified managed bytes', () {
      final identity = managedIdentity();
      final reference = HistoryByteReference.managed(identity);
      final state = ManagedByteRetentionState(
        identity: identity,
        retainedHistoryRevisionIds: const <int>[12],
        referenceAuditComplete: true,
      );

      expect(
        state.restoreabilityFor(
          reference: reference,
          revisionId: 12,
          managedByteVerifiedPresent: false,
        ),
        HistoryManagedByteRestoreability.metadataOnly,
      );
      expect(
        state.restoreabilityFor(
          reference: reference,
          revisionId: 11,
          managedByteVerifiedPresent: true,
        ),
        HistoryManagedByteRestoreability.metadataOnly,
      );
      expect(
        state.restoreabilityFor(
          reference: reference,
          revisionId: 12,
          managedByteVerifiedPresent: true,
        ),
        HistoryManagedByteRestoreability.retainedRestorable,
      );
    });

    test('managed reference cannot borrow another byte identity retention', () {
      final state = ManagedByteRetentionState(
        identity: managedIdentity(),
        retainedHistoryRevisionIds: const <int>[12],
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
          revisionId: 12,
          managedByteVerifiedPresent: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
