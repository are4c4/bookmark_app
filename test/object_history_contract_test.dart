import 'package:bookmark_app/domain/object_history_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObjectHistoryEntry', () {
    test(
      'captures stable durable identity and local-first source metadata',
      () {
        final capturedAt = DateTime.utc(2026, 9, 11, 6, 45);
        final entry = ObjectHistoryEntry(
          objectId: 7,
          revisionId: 3,
          previousRevisionId: 2,
          capturedAt: capturedAt,
          source: ObjectHistorySourceKind.userMutation,
        );

        expect(entry.objectId, 7);
        expect(entry.revisionId, 3);
        expect(entry.previousRevisionId, 2);
        expect(entry.capturedAt, capturedAt);
        expect(entry.source, ObjectHistorySourceKind.userMutation);
      },
    );

    test('malformed Object and revision identities fail closed', () {
      expect(
        () => ObjectHistoryEntry(
          objectId: 0,
          revisionId: 1,
          capturedAt: DateTime.utc(2026),
          source: ObjectHistorySourceKind.systemMutation,
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectHistoryEntry(
          objectId: 1,
          revisionId: 0,
          capturedAt: DateTime.utc(2026),
          source: ObjectHistorySourceKind.systemMutation,
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectHistoryEntry(
          objectId: 1,
          revisionId: 2,
          previousRevisionId: 2,
          capturedAt: DateTime.utc(2026),
          source: ObjectHistorySourceKind.systemMutation,
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectHistoryEntry(
          objectId: 1,
          revisionId: 2,
          previousRevisionId: -1,
          capturedAt: DateTime.utc(2026),
          source: ObjectHistorySourceKind.systemMutation,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ObjectHistoryRestoreScope', () {
    test('whole Object restore is distinct from selective restore', () {
      final whole = ObjectHistoryRestoreScope.wholeObject();
      final selective = ObjectHistoryRestoreScope.selective(
        <ObjectHistoryFieldTarget>[
          ObjectHistoryFieldTarget.title(),
          ObjectHistoryFieldTarget.property(12),
          ObjectHistoryFieldTarget.body(),
        ],
      );

      expect(whole.kind, ObjectHistoryRestoreScopeKind.wholeObject);
      expect(whole.targets, isEmpty);
      expect(selective.kind, ObjectHistoryRestoreScopeKind.selective);
      expect(selective.targets.map((target) => target.key), <String>[
        'title',
        'property:12',
        'body',
      ]);
    });

    test('empty, duplicate, and malformed selective targets fail closed', () {
      expect(
        () => ObjectHistoryRestoreScope.selective(
          const <ObjectHistoryFieldTarget>[],
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
          ObjectHistoryFieldTarget.title(),
          ObjectHistoryFieldTarget.title(),
        ]),
        throwsArgumentError,
      );
      expect(() => ObjectHistoryFieldTarget.property(0), throwsArgumentError);
    });
  });

  group('ObjectHistoryRestorePlan', () {
    test(
      'matching current revision is executable without Relation blockers',
      () {
        final plan = ObjectHistoryRestorePlan(
          objectId: 7,
          historicalRevisionId: 2,
          expectedCurrentRevisionId: 4,
          actualCurrentRevisionId: 4,
          scope: ObjectHistoryRestoreScope.wholeObject(),
        );

        expect(plan.hasCurrentRevisionConflict, isFalse);
        expect(plan.isExecutable, isTrue);
      },
    );

    test(
      'stale prepared revision fails closed against newer canonical state',
      () {
        final plan = ObjectHistoryRestorePlan(
          objectId: 7,
          historicalRevisionId: 2,
          expectedCurrentRevisionId: 4,
          actualCurrentRevisionId: 5,
          scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
            ObjectHistoryFieldTarget.body(),
          ]),
        );

        expect(plan.hasCurrentRevisionConflict, isTrue);
        expect(plan.isExecutable, isFalse);
      },
    );

    test(
      'Relation integrity blocker cannot be bypassed by A restore scope',
      () {
        final plan = ObjectHistoryRestorePlan(
          objectId: 7,
          historicalRevisionId: 2,
          expectedCurrentRevisionId: 4,
          actualCurrentRevisionId: 4,
          scope: ObjectHistoryRestoreScope.selective(<ObjectHistoryFieldTarget>[
            ObjectHistoryFieldTarget.title(),
          ]),
          relationBlockers: <ObjectHistoryRelationBlocker>[
            ObjectHistoryRelationBlocker(
              key: 'relation:author',
              reason: 'Historical targets violate current cardinality.',
            ),
          ],
        );

        expect(plan.isExecutable, isFalse);
        expect(plan.relationBlockers, hasLength(1));
      },
    );

    test('restore revision identities and ordering are validated', () {
      expect(
        () => ObjectHistoryRestorePlan(
          objectId: 0,
          historicalRevisionId: 1,
          expectedCurrentRevisionId: 2,
          actualCurrentRevisionId: 2,
          scope: ObjectHistoryRestoreScope.wholeObject(),
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectHistoryRestorePlan(
          objectId: 1,
          historicalRevisionId: 2,
          expectedCurrentRevisionId: 2,
          actualCurrentRevisionId: 2,
          scope: ObjectHistoryRestoreScope.wholeObject(),
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectHistoryRestorePlan(
          objectId: 1,
          historicalRevisionId: 1,
          expectedCurrentRevisionId: 0,
          actualCurrentRevisionId: 2,
          scope: ObjectHistoryRestoreScope.wholeObject(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('ObjectHistoryRetentionPolicy', () {
    test('retention intent is explicit without managed-byte authority', () {
      final keepAll = ObjectHistoryRetentionPolicy.keepAll();
      final bounded = ObjectHistoryRetentionPolicy.bounded(maxCheckpoints: 25);

      expect(keepAll.kind, ObjectHistoryRetentionKind.keepAll);
      expect(keepAll.maxCheckpoints, isNull);
      expect(bounded.kind, ObjectHistoryRetentionKind.boundedCheckpoints);
      expect(bounded.maxCheckpoints, 25);
    });

    test('bounded retention requires a positive checkpoint limit', () {
      expect(
        () => ObjectHistoryRetentionPolicy.bounded(maxCheckpoints: 0),
        throwsArgumentError,
      );
    });
  });
}
