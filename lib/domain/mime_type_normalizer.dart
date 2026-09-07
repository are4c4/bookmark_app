/// Shared normalization contract for persisted and routing MIME/content types.
///
/// Parameters are intentionally discarded because primitive identity/routing
/// only needs the media type itself. Malformed token shapes return `null` so
/// callers can keep missing-only enrichment and conservative fallback behavior.
class MimeTypeNormalizer {
  const MimeTypeNormalizer._();

  static final RegExp _mimeTypePattern = RegExp(
    r"^[a-z0-9!#$%&'*+.^_`|~-]+/[a-z0-9!#$%&'*+.^_`|~-]+$",
  );

  static String? normalize(String? value) {
    final candidate = value?.trim().toLowerCase();
    if (candidate == null || candidate.isEmpty) return null;
    final separator = candidate.indexOf(';');
    final mime = separator < 0
        ? candidate
        : candidate.substring(0, separator).trim();
    return _mimeTypePattern.hasMatch(mime) ? mime : null;
  }
}
