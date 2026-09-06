import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark resolver direct construction does not spread in presentation', () {
    const allowedLegacyHosts = <String>{
      'lib/views/bookmark_unified_stage1_page.dart',
    };

    final offenders = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final isPresentation = path.startsWith('lib/views/') ||
          path.startsWith('lib/widgets/') ||
          path.contains('/presentation/');
      if (!isPresentation) continue;

      final source = entity.readAsStringSync();
      if (source.contains('BookmarkUrlResolver(') ||
          source.contains('BookmarkVisualResolver(')) {
        offenders.add(path);
      }
    }

    expect(
      offenders.difference(allowedLegacyHosts),
      isEmpty,
      reason: 'New Bookmark presentation hosts must delegate resolver '
          'composition instead of constructing low-level resolvers directly. '
          'Removing an allowlisted legacy host is always allowed.',
    );
  });
}
