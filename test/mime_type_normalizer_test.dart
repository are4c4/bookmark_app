import 'package:bookmark_app/domain/mime_type_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes token-shaped MIME and strips parameters', () {
    expect(
      MimeTypeNormalizer.normalize(' Image/PNG; charset=UTF-8 '),
      'image/png',
    );
    expect(
      MimeTypeNormalizer.normalize('APPLICATION/VND.API+JSON'),
      'application/vnd.api+json',
    );
    expect(
      MimeTypeNormalizer.normalize("application/x-test!#$&'*+.^_`|~-value"),
      "application/x-test!#$&'*+.^_`|~-value",
    );
  });

  test('rejects incomplete or structurally malformed MIME values', () {
    for (final malformed in <String?>[
      null,
      '',
      'not-a-mime',
      'image/',
      '/png',
      'image/png/extra',
      'image / png',
      'image/ png',
      'image\\png',
    ]) {
      expect(
        MimeTypeNormalizer.normalize(malformed),
        isNull,
        reason: '$malformed',
      );
    }
  });
}
