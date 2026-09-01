import 'package:drift/native.dart';
import 'package:bookmark_app/data/app_database.dart';

Future<void> main(List<String> arguments) async {
  final counts = arguments.isEmpty
      ? const [1000, 5000, 10000]
      : arguments.map(int.parse).toList();

  for (final count in counts) {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      final seedWatch = Stopwatch()..start();
      await database.transaction(() async {
        for (var index = 0; index < count; index++) {
          await database.customStatement(
            'INSERT INTO bookmarks(url, title) VALUES (?, ?)',
            [
              'https://example.com/bookmark/$index',
              index % 10 == 0 ? 'Flutter benchmark $index' : 'Bookmark $index',
            ],
          );
        }
      });
      seedWatch.stop();

      final listWatch = Stopwatch()..start();
      final rows = await database.customSelect(
        'SELECT id, title FROM bookmarks ORDER BY id DESC LIMIT 100',
      ).get();
      listWatch.stop();

      final searchWatch = Stopwatch()..start();
      final matches = await database.customSelect(
        "SELECT id FROM bookmarks WHERE title LIKE '%Flutter%' LIMIT 100",
      ).get();
      searchWatch.stop();

      print(
        '$count records: seed=${seedWatch.elapsedMilliseconds}ms, '
        'list100=${listWatch.elapsedMicroseconds / 1000}ms, '
        'search=${searchWatch.elapsedMicroseconds / 1000}ms, '
        'rows=${rows.length}, matches=${matches.length}',
      );
    } finally {
      await database.close();
    }
  }
}
