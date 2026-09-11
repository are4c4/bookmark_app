import 'relation_mutation_service.dart';

typedef CanonicalObjectCommittedCallback = Future<void> Function(int objectId);
typedef CanonicalObjectDeletionCommittedCallback = Future<void> Function(
  RelationObjectDeletionImpact impact,
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
