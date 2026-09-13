import 'package:bookmark_app/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('older app fails closed without downgrading a newer Vault schema', () async {
    late dynamic rawDatabase;
    final executor = NativeDatabase.memory(
      setup: (sqlite) {
        rawDatabase = sqlite;
        sqlite.execute('CREATE TABLE rollback_sentinel (value TEXT NOT NULL)');
        sqlite.execute("INSERT INTO rollback_sentinel (value) VALUES ('preserve-me')");
        sqlite.execute('PRAGMA user_version = 17');
      },
    );
    final database = AppDatabase.forTesting(executor);

    await expectLater(
      database.customSelect('SELECT 1').get(),
      throwsA(
        isA<StateError>()
            .having(
              (error) => error.message,
              'message',
              contains('schema version 17'),
            )
            .having(
              (error) => error.message,
              'recovery guidance',
              contains('Reinstall a newer compatible Bookmark build'),
            ),
      ),
    );

    final versionRows = rawDatabase.select('PRAGMA user_version');
    expect(versionRows.first['user_version'], 17);
    final sentinelRows = rawDatabase.select('SELECT value FROM rollback_sentinel');
    expect(sentinelRows.first['value'], 'preserve-me');

    await database.close();
  });
}
