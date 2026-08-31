import 'package:bookmark_app/repositories/full_text_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildFtsPrefixQuery', () {
    test('builds prefix AND query from multiple terms', () {
      expect(
        buildFtsPrefixQuery('flutter bookmark'),
        '"flutter"* AND "bookmark"*',
      );
    });

    test('supports Japanese terms', () {
      expect(
        buildFtsPrefixQuery('数論 講義'),
        '"数論"* AND "講義"*',
      );
    });

    test('removes quotes and extra whitespace', () {
      expect(
        buildFtsPrefixQuery('  "hello"   world  '),
        '"hello"* AND "world"*',
      );
    });

    test('returns empty query for whitespace only input', () {
      expect(buildFtsPrefixQuery('   '), isEmpty);
    });
  });
}
