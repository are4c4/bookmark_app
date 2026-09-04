import 'object_model.dart';

/// Canonical Object identity returned by alias-aware search.
///
/// [object.id] is always the persisted identity. [matchedAlias] is optional UI
/// context only and must never be persisted as a Relation/reference identity.
class ObjectIdentitySearchResult {
  const ObjectIdentitySearchResult({
    required this.object,
    required this.objectType,
    required this.aliases,
    this.matchedAlias,
  });

  final AppObject object;
  final AppObjectType objectType;
  final List<String> aliases;
  final String? matchedAlias;

  int get objectId => object.id;
  String get canonicalTitle => object.title;

  String? get aliasContext => matchedAlias == null ? null : '別名: $matchedAlias';
}
