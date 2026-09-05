import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfilePathResolver', () {
    test('resolves relative stored paths under the profile root', () {
      const resolver = ProfilePathResolver('/profiles/current/');

      expect(
        resolver.resolveStoredPath('photos/cover.jpg'),
        '/profiles/current/photos/cover.jpg',
      );
      expect(
        resolver.resolveStoredPath(r'attachments\paper.pdf'),
        '/profiles/current/attachments/paper.pdf',
      );
    });

    test('keeps absolute paths unchanged', () {
      const resolver = ProfilePathResolver('/profiles/current');

      expect(resolver.resolveStoredPath('/tmp/photo.jpg'), '/tmp/photo.jpg');
      expect(
        resolver.resolveStoredPath(r'C:\Users\me\photo.jpg'),
        r'C:\Users\me\photo.jpg',
      );
    });

    test('stores paths inside the profile as relative values', () {
      const resolver = ProfilePathResolver('/profiles/current/');

      expect(
        resolver.toStoredPath('/profiles/current/photos/cover.jpg'),
        'photos/cover.jpg',
      );
      expect(resolver.toStoredPath('/profiles/current'), '.');
      expect(resolver.toStoredPath('/outside/photo.jpg'), '/outside/photo.jpg');
    });

    test('normalizes separators without a configured profile root', () {
      const resolver = ProfilePathResolver(null);

      expect(resolver.resolveStoredPath('photos/cover.jpg'), 'photos/cover.jpg');
      expect(resolver.toStoredPath(r'photos\cover.jpg'), 'photos/cover.jpg');
    });
  });
}
