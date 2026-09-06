import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ProfileManager fallback diagnostics omit raw exception text', () {
    final source = File('lib/services/profile_manager.dart').readAsStringSync();

    expect(
      source,
      contains(
        "stderr.writeln('ProfileManager: \$operation failed; using fallback.');",
      ),
    );
    expect(source, isNot(contains('using fallback: \$error')));
    expect(source, isNot(contains('Object error,')));
    expect(
      source,
      contains("_debugFallbackFailure('profile state load', stackTrace)"),
    );
    expect(
      source,
      contains(
        "_debugFallbackFailure('imported profile metadata read', stackTrace)",
      ),
    );
  });
}
