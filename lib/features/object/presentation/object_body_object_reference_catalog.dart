import '../../../data/object_identity_search_service.dart';
import 'widgets/object_body_object_reference_picker.dart';

/// Loads canonical Object identities for Body Object-reference insertion.
///
/// Aliases are search/display metadata only. Callers must persist [objectId]
/// from the returned candidate and never an alias string as reference identity.
class ObjectBodyObjectReferenceCatalog {
  const ObjectBodyObjectReferenceCatalog({required this.identitySearch});

  final ObjectIdentitySearchService identitySearch;

  Future<List<ObjectBodyObjectReferenceCandidate>> load({
    required int workspaceId,
  }) async {
    final results = await identitySearch.search(
      workspaceId: workspaceId,
      query: '',
    );
    return results
        .map(
          (result) => ObjectBodyObjectReferenceCandidate(
            objectId: result.objectId,
            title: result.canonicalTitle,
            objectTypeName: result.objectType.name,
            objectTypeIcon: result.objectType.icon,
            aliases: result.aliases,
          ),
        )
        .toList(growable: false);
  }
}
