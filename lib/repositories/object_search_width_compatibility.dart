/// Normalizes one Japanese/CJK Search fallback string for comparison.
///
/// This is deliberately narrower than Unicode NFKC. It folds only the
/// half-width Japanese punctuation/Katakana block and canonical Japanese
/// dakuten/handakuten composition differences. It does not transliterate,
/// fold kana scripts, or make arbitrary Latin infix search possible.
String normalizeCjkSearchCompatibilityText(String value) =>
    _composeCanonicalJapaneseSoundMarks(_normalizeHalfwidthJapanese(value));

/// Builds deterministic Japanese query-compatibility variants for one
/// canonical Search fallback term.
///
/// Kept for callers that need explicit representations. Canonical substring
/// comparison should normalize both the query needle and candidate projection
/// text with [normalizeCjkSearchCompatibilityText] so partially composed input
/// does not require enumerating every per-character composition combination.
List<String> buildCjkSearchCompatibilityVariants(String value) {
  final fullWidth = _normalizeHalfwidthJapanese(value);
  final composed = _composeCanonicalJapaneseSoundMarks(fullWidth);
  final decomposed = _decomposeCanonicalJapaneseSoundMarks(composed);
  final halfWidth = _toHalfwidthJapanese(composed);
  final halfWidthDecomposed = _toHalfwidthJapanese(decomposed);
  final variants = <String>[];
  for (final candidate in <String>[
    value,
    fullWidth,
    composed,
    decomposed,
    halfWidth,
    halfWidthDecomposed,
  ]) {
    if (candidate.isEmpty || variants.contains(candidate)) continue;
    variants.add(candidate);
  }
  return List<String>.unmodifiable(variants);
}

/// Compatibility entrypoint retained for existing explicit-variant callers.
List<String> buildCjkWidthCompatibilityVariants(String value) =>
    buildCjkSearchCompatibilityVariants(value);

String _normalizeHalfwidthJapanese(String value) {
  final runes = value.runes.toList(growable: false);
  final normalized = <int>[];
  for (var index = 0; index < runes.length; index += 1) {
    final rune = runes[index];
    final fullWidth = _halfwidthJapaneseToFullwidth[rune];
    if (fullWidth == null) {
      normalized.add(rune);
      continue;
    }

    if (index + 1 < runes.length) {
      final mark = runes[index + 1];
      final composed = mark == 0xff9e
          ? _dakutenCompositions[fullWidth]
          : mark == 0xff9f
          ? _handakutenCompositions[fullWidth]
          : null;
      if (composed != null) {
        normalized.add(composed);
        index += 1;
        continue;
      }
    }
    normalized.add(fullWidth);
  }
  return String.fromCharCodes(normalized);
}

String _composeCanonicalJapaneseSoundMarks(String value) {
  final runes = value.runes.toList(growable: false);
  final composed = <int>[];
  for (var index = 0; index < runes.length; index += 1) {
    final rune = runes[index];
    if (index + 1 < runes.length) {
      final mark = runes[index + 1];
      final replacement = mark == 0x3099
          ? _dakutenCompositions[rune]
          : mark == 0x309a
          ? _handakutenCompositions[rune]
          : null;
      if (replacement != null) {
        composed.add(replacement);
        index += 1;
        continue;
      }
    }
    composed.add(rune);
  }
  return String.fromCharCodes(composed);
}

String _decomposeCanonicalJapaneseSoundMarks(String value) {
  final decomposed = <int>[];
  for (final rune in value.runes) {
    final dakutenBase = _dakutenDecompositions[rune];
    if (dakutenBase != null) {
      decomposed
        ..add(dakutenBase)
        ..add(0x3099);
      continue;
    }
    final handakutenBase = _handakutenDecompositions[rune];
    if (handakutenBase != null) {
      decomposed
        ..add(handakutenBase)
        ..add(0x309a);
      continue;
    }
    decomposed.add(rune);
  }
  return String.fromCharCodes(decomposed);
}

String _toHalfwidthJapanese(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final voiced = _precomposedToHalfwidth[rune];
    if (voiced != null) {
      buffer.write(voiced);
      continue;
    }
    final halfWidth = _fullwidthJapaneseToHalfwidth[rune];
    if (halfWidth != null) {
      buffer.write(String.fromCharCode(halfWidth));
      continue;
    }
    buffer.write(String.fromCharCode(rune));
  }
  return buffer.toString();
}

const Map<int, int> _halfwidthJapaneseToFullwidth = <int, int>{
  0xff61: 0x3002,
  0xff62: 0x300c,
  0xff63: 0x300d,
  0xff64: 0x3001,
  0xff65: 0x30fb,
  0xff66: 0x30f2,
  0xff67: 0x30a1,
  0xff68: 0x30a3,
  0xff69: 0x30a5,
  0xff6a: 0x30a7,
  0xff6b: 0x30a9,
  0xff6c: 0x30e3,
  0xff6d: 0x30e5,
  0xff6e: 0x30e7,
  0xff6f: 0x30c3,
  0xff70: 0x30fc,
  0xff71: 0x30a2,
  0xff72: 0x30a4,
  0xff73: 0x30a6,
  0xff74: 0x30a8,
  0xff75: 0x30aa,
  0xff76: 0x30ab,
  0xff77: 0x30ad,
  0xff78: 0x30af,
  0xff79: 0x30b1,
  0xff7a: 0x30b3,
  0xff7b: 0x30b5,
  0xff7c: 0x30b7,
  0xff7d: 0x30b9,
  0xff7e: 0x30bb,
  0xff7f: 0x30bd,
  0xff80: 0x30bf,
  0xff81: 0x30c1,
  0xff82: 0x30c4,
  0xff83: 0x30c6,
  0xff84: 0x30c8,
  0xff85: 0x30ca,
  0xff86: 0x30cb,
  0xff87: 0x30cc,
  0xff88: 0x30cd,
  0xff89: 0x30ce,
  0xff8a: 0x30cf,
  0xff8b: 0x30d2,
  0xff8c: 0x30d5,
  0xff8d: 0x30d8,
  0xff8e: 0x30db,
  0xff8f: 0x30de,
  0xff90: 0x30df,
  0xff91: 0x30e0,
  0xff92: 0x30e1,
  0xff93: 0x30e2,
  0xff94: 0x30e4,
  0xff95: 0x30e6,
  0xff96: 0x30e8,
  0xff97: 0x30e9,
  0xff98: 0x30ea,
  0xff99: 0x30eb,
  0xff9a: 0x30ec,
  0xff9b: 0x30ed,
  0xff9c: 0x30ef,
  0xff9d: 0x30f3,
  0xff9e: 0x309b,
  0xff9f: 0x309c,
};

final Map<int, int> _fullwidthJapaneseToHalfwidth = <int, int>{
  for (final entry in _halfwidthJapaneseToFullwidth.entries)
    entry.value: entry.key,
};

const Map<int, int> _dakutenCompositions = <int, int>{
  0x304b: 0x304c,
  0x304d: 0x304e,
  0x304f: 0x3050,
  0x3051: 0x3052,
  0x3053: 0x3054,
  0x3055: 0x3056,
  0x3057: 0x3058,
  0x3059: 0x305a,
  0x305b: 0x305c,
  0x305d: 0x305e,
  0x305f: 0x3060,
  0x3061: 0x3062,
  0x3064: 0x3065,
  0x3066: 0x3067,
  0x3068: 0x3069,
  0x306f: 0x3070,
  0x3072: 0x3073,
  0x3075: 0x3076,
  0x3078: 0x3079,
  0x307b: 0x307c,
  0x3046: 0x3094,
  0x309d: 0x309e,
  0x30ab: 0x30ac,
  0x30ad: 0x30ae,
  0x30af: 0x30b0,
  0x30b1: 0x30b2,
  0x30b3: 0x30b4,
  0x30b5: 0x30b6,
  0x30b7: 0x30b8,
  0x30b9: 0x30ba,
  0x30bb: 0x30bc,
  0x30bd: 0x30be,
  0x30bf: 0x30c0,
  0x30c1: 0x30c2,
  0x30c4: 0x30c5,
  0x30c6: 0x30c7,
  0x30c8: 0x30c9,
  0x30cf: 0x30d0,
  0x30d2: 0x30d3,
  0x30d5: 0x30d6,
  0x30d8: 0x30d9,
  0x30db: 0x30dc,
  0x30a6: 0x30f4,
  0x30ef: 0x30f7,
  0x30f0: 0x30f8,
  0x30f1: 0x30f9,
  0x30f2: 0x30fa,
  0x30fd: 0x30fe,
};

const Map<int, int> _handakutenCompositions = <int, int>{
  0x306f: 0x3071,
  0x3072: 0x3074,
  0x3075: 0x3077,
  0x3078: 0x307a,
  0x307b: 0x307d,
  0x30cf: 0x30d1,
  0x30d2: 0x30d4,
  0x30d5: 0x30d7,
  0x30d8: 0x30da,
  0x30db: 0x30dd,
};

final Map<int, int> _dakutenDecompositions = <int, int>{
  for (final entry in _dakutenCompositions.entries) entry.value: entry.key,
};

final Map<int, int> _handakutenDecompositions = <int, int>{
  for (final entry in _handakutenCompositions.entries) entry.value: entry.key,
};

const Map<int, String> _precomposedToHalfwidth = <int, String>{
  0x30f4: 'ｳﾞ',
  0x30ac: 'ｶﾞ',
  0x30ae: 'ｷﾞ',
  0x30b0: 'ｸﾞ',
  0x30b2: 'ｹﾞ',
  0x30b4: 'ｺﾞ',
  0x30b6: 'ｻﾞ',
  0x30b8: 'ｼﾞ',
  0x30ba: 'ｽﾞ',
  0x30bc: 'ｾﾞ',
  0x30be: 'ｿﾞ',
  0x30c0: 'ﾀﾞ',
  0x30c2: 'ﾁﾞ',
  0x30c5: 'ﾂﾞ',
  0x30c7: 'ﾃﾞ',
  0x30c9: 'ﾄﾞ',
  0x30d0: 'ﾊﾞ',
  0x30d3: 'ﾋﾞ',
  0x30d6: 'ﾌﾞ',
  0x30d9: 'ﾍﾞ',
  0x30dc: 'ﾎﾞ',
  0x30d1: 'ﾊﾟ',
  0x30d4: 'ﾋﾟ',
  0x30d7: 'ﾌﾟ',
  0x30da: 'ﾍﾟ',
  0x30dd: 'ﾎﾟ',
  0x30f7: 'ﾜﾞ',
  0x30f8: 'ｲﾞ',
  0x30f9: 'ｴﾞ',
  0x30fa: 'ｦﾞ',
};
