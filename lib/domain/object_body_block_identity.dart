import 'object_body.dart';

/// Allocates stable, human-readable Body block ids without requiring hosts to
/// depend on persistence or a UUID package.
///
/// Allocation is deterministic against the current document and never reuses
/// an existing id. Hosts may provide a semantic prefix, but blank/unsafe
/// prefixes fall back to `block`.
class ObjectBodyBlockIdAllocator {
  const ObjectBodyBlockIdAllocator();

  String next(ObjectBodyDocument document, {String prefix = 'block'}) {
    final normalizedPrefix = _normalizePrefix(prefix);
    final used = document.blocks.map((block) => block.id).toSet();
    var sequence = 1;
    while (used.contains('$normalizedPrefix-$sequence')) {
      sequence++;
    }
    return '$normalizedPrefix-$sequence';
  }

  String _normalizePrefix(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized.isEmpty ? 'block' : normalized;
  }
}

/// Creates a duplicate block payload with a new identity while preserving all
/// known and unknown attributes verbatim.
class ObjectBodyBlockDuplicator {
  const ObjectBodyBlockDuplicator();

  ObjectBodyBlock duplicate({
    required ObjectBodyBlock source,
    required String newId,
  }) {
    final normalized = newId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(newId, 'newId', 'Block id is empty.');
    }
    if (normalized == source.id) {
      throw ArgumentError.value(
        newId,
        'newId',
        'Duplicate block must receive a new identity.',
      );
    }
    return ObjectBodyBlock(
      id: normalized,
      type: source.type,
      text: source.text,
      attributes: Map<String, dynamic>.from(source.attributes),
    );
  }
}
