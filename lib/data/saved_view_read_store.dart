import 'package:drift/drift.dart';

import 'app_database.dart';

class SavedViewReadStore {
  const SavedViewReadStore(this.database);

  final AppDatabase database;

  Future<List<Tag>> _tagsForSavedView(int savedViewId) {
    final query = database.select(database.tags).join([
      innerJoin(
        database.savedViewTags,
        database.savedViewTags.tagId.equalsExp(database.tags.id),
      ),
    ])
      ..where(database.savedViewTags.savedViewId.equals(savedViewId))
      ..orderBy([OrderingTerm.asc(database.tags.name)]);
    return query.map((row) => row.readTable(database.tags)).get();
  }

  Stream<List<SavedViewConfig>> watchConfigs() {
    final trigger = database.customSelect(
      'SELECT sv.id FROM saved_views sv '
      'LEFT JOIN saved_view_tags svt ON svt.saved_view_id = sv.id '
      'GROUP BY sv.id',
      readsFrom: {
        database.savedViews,
        database.savedViewTags,
        database.tags,
      },
    ).watch();

    return trigger.asyncMap((_) async {
      final rows = await (database.select(database.savedViews)
            ..orderBy([
              (view) => OrderingTerm.asc(view.createdAt),
            ]))
          .get();
      return Future.wait(
        rows.map(
          (view) async => SavedViewConfig(
            view: view,
            tags: await _tagsForSavedView(view.id),
          ),
        ),
      );
    });
  }
}
