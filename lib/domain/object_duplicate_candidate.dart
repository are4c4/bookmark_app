enum ObjectDuplicateIdentityKind { canonicalTitle, alias }

/// Why one proposed identity term overlaps an existing Object identity term.
class ObjectDuplicateIdentityMatch {
  const ObjectDuplicateIdentityMatch({
    required this.proposedKind,
    required this.proposedValue,
    required this.existingKind,
    required this.existingValue,
  });

  final ObjectDuplicateIdentityKind proposedKind;
  final String proposedValue;
  final ObjectDuplicateIdentityKind existingKind;
  final String existingValue;
}

/// Read-only advisory duplicate candidate for one canonical Object identity.
///
/// A candidate never implies merge, reuse, redirect, or mutation authority.
class ObjectDuplicateCandidate {
  ObjectDuplicateCandidate({
    required this.objectId,
    required this.objectTypeId,
    required this.canonicalTitle,
    required List<ObjectDuplicateIdentityMatch> matches,
  }) : matches = List<ObjectDuplicateIdentityMatch>.unmodifiable(matches) {
    if (objectId <= 0 || objectTypeId <= 0) {
      throw ArgumentError(
        'Duplicate candidate Object identities must be positive.',
      );
    }
    if (matches.isEmpty) {
      throw ArgumentError.value(
        matches,
        'matches',
        'Duplicate candidates require at least one exact identity match.',
      );
    }
  }

  final int objectId;
  final int objectTypeId;
  final String canonicalTitle;
  final List<ObjectDuplicateIdentityMatch> matches;
}
