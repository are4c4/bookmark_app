import 'app_database.dart';
import 'relation_mutation_service.dart';

typedef CanonicalObjectCommittedCallback = Future<void> Function(int objectId);
typedef CanonicalObjectDeletionCommittedCallback = Future<void> Function(
  RelationObjectDeletionImpact impact,
);

final Expando<CanonicalObjectMutationImpactSink>
_canonicalObjectMutationImpactSinks =
    Expando<CanonicalObjectMutationImpactSink>(
      'canonical-object-mutation-impact-sinks',
    );

/// Application-composition sink for committed canonical Object mutation impact.
///
/// Mutation owners report only canonical ids after their transaction commits.
/// The sink deliberately knows nothing about Search, UI, legacy Person ids or
/// persistence details, so derived projection owners can be composed at the app
/// boundary without introducing a domain-specific index or a general event bus.
class CanonicalObjectMutationImpactSink {
  const CanonicalObjectMutationImpactSink({
    required this.onObjectCommitted,
    required this.onDeletionCommitted,
  });

  final CanonicalObjectCommittedCallback onObjectCommitted;
  final CanonicalObjectDeletionCommittedCallback onDeletionCommitted;

  Future<void> objectCommitted(int objectId) => onObjectCommitted(objectId);

  Future<void> deletionCommitted(RelationObjectDeletionImpact impact) =>
      onDeletionCommitted(impact);
}

/// Binds one runtime-only canonical mutation sink to an open AppDatabase.
///
/// This is a narrow composition lookup, not a broadcast mutation bus: one
/// database resolves to at most one sink and callers still invoke it explicitly
/// only after a canonical transaction commits. Expando lifetime also keeps the
/// binding scoped to the database instance rather than persisted application
/// state.
void bindCanonicalObjectMutationImpactSink({
  required AppDatabase database,
  required CanonicalObjectMutationImpactSink sink,
}) {
  _canonicalObjectMutationImpactSinks[database] = sink;
}

CanonicalObjectMutationImpactSink? canonicalObjectMutationImpactSinkFor(
  AppDatabase database,
) => _canonicalObjectMutationImpactSinks[database];
