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

  test('failed duplicate/import cleanup cannot replace the primary failure', () {
    final source = File('lib/services/profile_manager.dart').readAsStringSync();

    expect(
      source,
      contains(
        "await _discardFailedAppManagedProfile(\n"
        "        copy,\n"
        "        'failed profile duplication cleanup',\n"
        '      );\n'
        '      rethrow;',
      ),
    );
    expect(
      source,
      contains(
        "await _discardFailedAppManagedProfile(\n"
        "        copy,\n"
        "        'failed profile import cleanup',\n"
        '      );\n'
        '      rethrow;',
      ),
    );
    expect(
      source,
      contains(
        'try {\n'
        '      await _discardAppManagedProfile(profile);\n'
        '    } catch (_, stackTrace) {',
      ),
    );
    expect(source, contains('_debugFallbackFailure(operation, stackTrace);'));
    expect(source, isNot(contains('_debugFallbackFailure(operation, error')));
  });
}
