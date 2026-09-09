import '../domain/object_model.dart';
import 'weblink_object_service.dart';

/// Canonical application boundary for direct URL capture.
///
/// Identity is established before optional metadata/enrichment. The capture is
/// serialized by the database transaction so concurrent callers cannot both
/// observe "missing" and create separate Weblink Objects. Existing canonical
/// collisions fail closed instead of choosing one target arbitrarily.
class CanonicalWeblinkCaptureService {
  const CanonicalWeblinkCaptureService({
    required WeblinkObjectService weblinks,
  }) : _weblinks = weblinks;

  final WeblinkObjectService _weblinks;

  Future<AppObject> capture({
    required int workspaceId,
    required String url,
    String? title,
  }) async {
    // Validate before any schema/Object write so malformed input is fail-closed.
    final normalizedUrl = _weblinks.normalizeUrl(url);
    final definition = await _weblinks.ensureDefinition(workspaceId);

    return _weblinks.systemObjects.database.transaction(() async {
      final before = await _matchingCanonicalObjects(
        objectTypeId: definition.objectType.id,
        urlPropertyId: definition.urlProperty.id,
        normalizedUrl: normalizedUrl,
      );
      _requireUniqueCanonicalTarget(
        normalizedUrl: normalizedUrl,
        matches: before,
      );

      final captured = await _weblinks.findOrCreate(
        workspaceId: workspaceId,
        url: normalizedUrl,
        title: title,
      );

      final after = await _matchingCanonicalObjects(
        objectTypeId: definition.objectType.id,
        urlPropertyId: definition.urlProperty.id,
        normalizedUrl: normalizedUrl,
      );
      _requireUniqueCanonicalTarget(
        normalizedUrl: normalizedUrl,
        matches: after,
      );
      if (after.single.id != captured.id) {
        throw StateError(
          'Canonical Weblink capture resolved an unexpected target for '
          '$normalizedUrl.',
        );
      }
      return captured;
    });
  }

  Future<List<AppObject>> _matchingCanonicalObjects({
    required int objectTypeId,
    required int urlPropertyId,
    required String normalizedUrl,
  }) async {
    final matches = <AppObject>[];
    final objects = await _weblinks.systemObjects.objectStore.listObjects(
      objectTypeId,
    );
    for (final object in objects) {
      final stored = '${object.values[urlPropertyId] ?? ''}'.trim();
      if (stored.isEmpty) continue;
      try {
        if (_weblinks.normalizeUrl(stored) == normalizedUrl) {
          matches.add(object);
        }
      } on ArgumentError {
        // Unrelated malformed historical data remains preserved. It must not be
        // repaired or interpreted as the target of a valid new capture.
      }
    }
    return matches;
  }

  void _requireUniqueCanonicalTarget({
    required String normalizedUrl,
    required List<AppObject> matches,
  }) {
    if (matches.length <= 1) return;
    throw StateError(
      'Canonical Weblink collision: ${matches.length} Objects resolve to '
      '$normalizedUrl.',
    );
  }
}
