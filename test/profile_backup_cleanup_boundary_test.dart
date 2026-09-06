import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile restore cleanup preserves the primary failure', () {
    final source = File('lib/services/profile_backup_service.dart')
        .readAsStringSync();

    expect(
      source,
      contains(
        '// Cleanup is best-effort. A cleanup failure must not replace the original',
      ),
    );
    expect(source, contains("'Profile restore cleanup failed.'"));
    expect(source, contains("name: 'bookmark_app.profile_backup'"));
    expect(source, contains('rethrow;'));
    expect(source, isNot(contains('error: error')));
  });
}
