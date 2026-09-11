import 'package:bookmark_app/domain/object_merge_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObjectMergePreview', () {
    test('no-conflict preview is executable without decisions', () {
      final preview = ObjectMergePreview(
        survivorId: 10,
        retiredId: 20,
        requirements: <ObjectMergeRequirement>[
          ObjectMergeRequirement.compatible(
            key: 'title',
            kind: ObjectMergeStateKind.title,
          ),
          ObjectMergeRequirement.compatible(
            key: 'body',
            kind: ObjectMergeStateKind.body,
          ),
        ],
      );

      expect(preview.plan().isExecutable, isTrue);
    });

    test('conflicting Object state requires explicit allowed decisions', () {
      final preview = ObjectMergePreview(
        survivorId: 10,
        retiredId: 20,
        requirements: <ObjectMergeRequirement>[
          ObjectMergeRequirement.conflict(
            key: 'title',
            kind: ObjectMergeStateKind.title,
            allowedDecisions: const <ObjectMergeDecision>{
              ObjectMergeDecision.keepSurvivor,
              ObjectMergeDecision.takeRetired,
            },
          ),
          ObjectMergeRequirement.conflict(
            key: 'property:rating',
            kind: ObjectMergeStateKind.property,
            allowedDecisions: const <ObjectMergeDecision>{
              ObjectMergeDecision.keepSurvivor,
              ObjectMergeDecision.takeRetired,
            },
          ),
          ObjectMergeRequirement.conflict(
            key: 'body',
            kind: ObjectMergeStateKind.body,
            allowedDecisions: const <ObjectMergeDecision>{
              ObjectMergeDecision.keepSurvivor,
              ObjectMergeDecision.takeRetired,
            },
          ),
          ObjectMergeRequirement.conflict(
            key: 'aliases',
            kind: ObjectMergeStateKind.aliases,
            allowedDecisions: const <ObjectMergeDecision>{
              ObjectMergeDecision.keepSurvivor,
              ObjectMergeDecision.takeRetired,
              ObjectMergeDecision.combine,
            },
          ),
          ObjectMergeRequirement.conflict(
            key: 'lifecycle',
            kind: ObjectMergeStateKind.lifecycle,
            allowedDecisions: const <ObjectMergeDecision>{
              ObjectMergeDecision.keepSurvivor,
              ObjectMergeDecision.takeRetired,
            },
          ),
        ],
      );

      var plan = preview.plan();
      expect(plan.isExecutable, isFalse);

      plan = plan
          .withDecision('title', ObjectMergeDecision.keepSurvivor)
          .withDecision('property:rating', ObjectMergeDecision.takeRetired)
          .withDecision('body', ObjectMergeDecision.keepSurvivor)
          .withDecision('aliases', ObjectMergeDecision.combine)
          .withDecision('lifecycle', ObjectMergeDecision.keepSurvivor);

      expect(plan.isExecutable, isTrue);
      expect(plan.decisions['aliases'], ObjectMergeDecision.combine);
    });

    test('unsupported or unrelated decisions fail closed', () {
      final preview = ObjectMergePreview(
        survivorId: 1,
        retiredId: 2,
        requirements: <ObjectMergeRequirement>[
          ObjectMergeRequirement.conflict(
            key: 'body',
            kind: ObjectMergeStateKind.body,
            allowedDecisions: const <ObjectMergeDecision>{
              ObjectMergeDecision.keepSurvivor,
              ObjectMergeDecision.takeRetired,
            },
          ),
          ObjectMergeRequirement.compatible(
            key: 'title',
            kind: ObjectMergeStateKind.title,
          ),
        ],
      );

      expect(
        () => preview.plan(
          decisions: const <String, ObjectMergeDecision>{
            'body': ObjectMergeDecision.combine,
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => preview.plan(
          decisions: const <String, ObjectMergeDecision>{
            'title': ObjectMergeDecision.keepSurvivor,
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => preview.plan(
          decisions: const <String, ObjectMergeDecision>{
            'unknown': ObjectMergeDecision.keepSurvivor,
          },
        ),
        throwsArgumentError,
      );
    });

    test('Relation blocker cannot be bypassed by Object decisions', () {
      final preview = ObjectMergePreview(
        survivorId: 1,
        retiredId: 2,
        requirements: <ObjectMergeRequirement>[
          ObjectMergeRequirement.conflict(
            key: 'title',
            kind: ObjectMergeStateKind.title,
            allowedDecisions: const <ObjectMergeDecision>{
              ObjectMergeDecision.keepSurvivor,
              ObjectMergeDecision.takeRetired,
            },
          ),
        ],
        relationBlockers: <ObjectMergeRelationBlocker>[
          ObjectMergeRelationBlocker(
            key: 'relation:author',
            reason: 'Retargeting would violate one-target cardinality.',
          ),
        ],
      );

      final plan = preview.plan(
        decisions: const <String, ObjectMergeDecision>{
          'title': ObjectMergeDecision.keepSurvivor,
        },
      );

      expect(plan.isExecutable, isFalse);
      expect(preview.hasRelationBlockers, isTrue);
    });

    test('invalid identities and malformed requirements fail closed', () {
      expect(
        () => ObjectMergePreview(survivorId: 0, retiredId: 2),
        throwsArgumentError,
      );
      expect(
        () => ObjectMergePreview(survivorId: 2, retiredId: 2),
        throwsArgumentError,
      );
      expect(
        () => ObjectMergeRequirement.conflict(
          key: 'body',
          kind: ObjectMergeStateKind.body,
          allowedDecisions: const <ObjectMergeDecision>{},
        ),
        throwsArgumentError,
      );
      expect(
        () => ObjectMergePreview(
          survivorId: 1,
          retiredId: 2,
          requirements: <ObjectMergeRequirement>[
            ObjectMergeRequirement.compatible(
              key: 'title',
              kind: ObjectMergeStateKind.title,
            ),
            ObjectMergeRequirement.compatible(
              key: 'title',
              kind: ObjectMergeStateKind.title,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('ObjectRedirectResolver', () {
    const resolver = ObjectRedirectResolver();

    test('redirect chain resolves to one stable final canonical id', () {
      const redirects = <int, int>{30: 20, 20: 10};

      expect(resolver.resolve(objectId: 30, redirects: redirects), 10);
      expect(resolver.resolve(objectId: 20, redirects: redirects), 10);
      expect(resolver.resolve(objectId: 10, redirects: redirects), 10);
      expect(
        resolver.resolve(
          objectId: resolver.resolve(objectId: 30, redirects: redirects),
          redirects: redirects,
        ),
        10,
      );
    });

    test('invalid redirect ids and self redirects fail closed', () {
      expect(
        () => resolver.resolve(objectId: 0, redirects: const <int, int>{}),
        throwsArgumentError,
      );
      expect(
        () => resolver.resolve(
          objectId: 1,
          redirects: const <int, int>{0: 2},
        ),
        throwsStateError,
      );
      expect(
        () => resolver.resolve(
          objectId: 1,
          redirects: const <int, int>{1: 1},
        ),
        throwsStateError,
      );
    });

    test('cycles fail closed even when they are outside the requested chain', () {
      expect(
        () => resolver.resolve(
          objectId: 10,
          redirects: const <int, int>{20: 30, 30: 20},
        ),
        throwsStateError,
      );
    });
  });
}
