import 'object_model.dart';

/// Canonical Object identity returned by alias-aware search.
///
/// [object.id] is always the persisted identity. [matchedAlias] and
/// [presentationContext] are optional UI context only and must never be
/// persisted as a Relation/reference identity.
class ObjectIdentitySearchResult {
  const ObjectIdentitySearchResult({
    required this.object,
    required this.objectType,
    required this.aliases,
    this.matchedAlias,
    this.presentationContext,
  });

  final AppObject object;
  final AppObjectType objectType;
  final List<String> aliases;
  final String? matchedAlias;

  /// Optional read-only context added by a presentation adapter.
  ///
  /// Canonical search itself leaves this null. Relation-picker specializations
  /// may use it for derived context such as a Tag hierarchy path without
  /// changing the Object identity or persisted Relation value.
  final String? presentationContext;

  int get objectId => object.id;
  String get canonicalTitle => object.title;

  String? get aliasContext {
    final contexts = <String>[
      if (presentationContext?.trim().isNotEmpty == true)
        presentationContext!.trim(),
      if (matchedAlias != null) '別名: $matchedAlias',
    ];
    return contexts.isEmpty ? null : contexts.join(' · ');
  }
}
