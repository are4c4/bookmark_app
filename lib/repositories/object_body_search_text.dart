import '../domain/object_body.dart';
import '../domain/object_body_block_contracts.dart';

/// Builds the deterministic user-facing text contributed by an Object Body to
/// the canonical search projection.
///
/// Search text intentionally follows persisted block order, includes text from
/// unknown/future block kinds, and includes asset captions. Structural ids and
/// other machine-only attributes are never emitted.
String buildObjectBodySearchText(ObjectBody body) {
  final fragments = <String>[];
  for (final block in body.blocks) {
    _appendSearchFragment(fragments, block.text);

    final caption = block.attributes[ObjectBodyBlockAttribute.caption];
    if (caption is String && caption != block.text) {
      _appendSearchFragment(fragments, caption);
    }
  }
  return fragments.join('\n');
}

void _appendSearchFragment(List<String> target, String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return;
  target.add(normalized);
}
