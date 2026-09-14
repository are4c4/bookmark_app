import 'dart:io';

import 'package:bookmark_app/services/backup_output_file_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writer failure remains primary and removes the staged file', () async {
    final root = await Directory.systemTemp.createTemp('backup-output-test-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final destination = File('${root.path}/backup.zip');
    final primary = StateError('primary backup writer failure');

    await expectLater(
      const BackupOutputFileService().write(
        destinationPath: destination.path,
        writer: (stagedPath) async {
          await File(stagedPath).writeAsString('partial');
          throw primary;
        },
      ),
      throwsA(same(primary)),
    );

    expect(await destination.exists(), isFalse);
    final leftovers = await root.list().toList();
    expect(leftovers, isEmpty);
  });

  test('cleanup boundary preserves primary failure and diagnostic privacy', () {
    final source = File('lib/services/backup_output_file_service.dart')
        .readAsStringSync();

    expect(
      source,
      contains(
        '// Cleanup is best-effort. A cleanup failure must not replace the original',
      ),
    );
    expect(
      source,
      contains(
        "developer.log(\n"
        "            'Backup output staging cleanup failed.',\n"
        "            name: 'bookmark_app.backup_output',\n"
        '            stackTrace: stackTrace,\n'
        '          );',
      ),
    );
    expect(source, contains('rethrow;'));
    expect(source, isNot(contains('error: error')));
  });
}
