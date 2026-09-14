import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'rollback cleanup diagnostics preserve primary-failure privacy contract',
    () {
      final source = File('lib/services/vault_move_copy_service.dart')
          .readAsStringSync();

      expect(
        source,
        contains("_debugCleanupFailure('copied file cleanup', stackTrace);"),
      );
      expect(
        source,
        contains(
          "_debugCleanupFailure('created directory cleanup', stackTrace);",
        ),
      );
      expect(
        source,
        contains("_debugCleanupFailure('created root cleanup', stackTrace);"),
      );
      expect(source, contains('} catch (_, stackTrace) {'));
      expect(
        source,
        contains(
          "'VaultMoveCopyService: \$operation failed during rollback.',",
        ),
      );
      expect(source, isNot(contains('catch (error, stackTrace)')));
      expect(source, isNot(contains('stderr.writeln(error)')));
    },
  );
}
