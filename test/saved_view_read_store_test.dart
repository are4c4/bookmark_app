import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/saved_view_read_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SavedViewReadStore store;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = SavedViewReadStore(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('watchConfigs preserves view ordering and sorted tag aggregation',
      () async {
    final alphaId = await database.createTag('Alpha');
    final zuluId = await database.createTag('Zulu');

    await database.into(database.savedViews).insert(
          SavedViewsCompanion.insert(
            name: 'Later',
            createdAt: Value(DateTime(2026, 1, 2)),
          ),
        );
    final earlierId = await database.into(database.savedViews).insert(
          SavedViewsCompanion.insert(
            name: 'Earlier',
            createdAt: Value(DateTime(2026, 1, 1)),
          ),
        );

    await database.into(database.savedViewTags).insert(
          SavedViewTagsCompanion.insert(
            savedViewId: earlierId,
            tagId: zuluId,
          ),
        );
    await database.into(database.savedViewTags).insert(
          SavedViewTagsCompanion.insert(
            savedViewId: earlierId,
            tagId: alphaId,
          ),
        );

    final configs = await store.watchConfigs().first;

    expect(configs.map((config) => config.view.name), ['Earlier', 'Later']);
    expect(
      configs.first.tags.map((tag) => tag.name),
      ['Alpha', 'Zulu'],
    );
    expect(configs.last.tags, isEmpty);
  });
}
