import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get thumbnail => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant(''))(); // legacy
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get parentTagId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class BookmarkTags extends Table {
  IntColumn get bookmarkId => integer().references(
        Bookmarks,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get tagId => integer().references(
        Tags,
        #id,
        onDelete: KeyAction.cascade,
      )();

  @override
  Set<Column<Object>> get primaryKey => {bookmarkId, tagId};
}

class SavedViews extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get layoutType => text().withDefault(const Constant('gallery'))();
  TextColumn get searchQuery => text().withDefault(const Constant(''))();
  BoolColumn get favoritesOnly => boolean().withDefault(const Constant(false))();

  // Legacy v3 filter. v4+ uses SavedViewTags.
  IntColumn get tagId => integer().nullable().references(
        Tags,
        #id,
        onDelete: KeyAction.setNull,
      )();

  TextColumn get tagMatchMode => text().withDefault(const Constant('or'))();
  TextColumn get sortField => text().withDefault(const Constant('createdAt'))();
  TextColumn get sortDirection => text().withDefault(const Constant('desc'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SavedViewTags extends Table {
  IntColumn get savedViewId => integer().references(
        SavedViews,
        #id,
        onDelete: KeyAction.cascade,
      )();
  IntColumn get tagId => integer().references(
        Tags,
        #id,
        onDelete: KeyAction.cascade,
      )();

  @override
  Set<Column<Object>> get primaryKey => {savedViewId, tagId};
}

class BookmarkItem {
  const BookmarkItem({
    required this.id,
    required this.url,
    required this.title,
    required this.createdAt,
    required this.favorite,
    required this.tags,
    this.thumbnail,
    this.description,
  });

  final int id;
  final String url;
  final String title;
  final String? thumbnail;
  final String? description;
  final DateTime createdAt;
  final bool favorite;
  final List<Tag> tags;
}

class SavedViewConfig {
  const SavedViewConfig({required this.view, required this.tags});

  final SavedView view;
  final List<Tag> tags;
}

@DriftDatabase(
  tables: [Bookmarks, Tags, BookmarkTags, SavedViews, SavedViewTags],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'bookmark_app'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(bookmarks, bookmarks.tags);
          }

          if (from < 3) {
            await m.createTable(tags);
            await m.createTable(bookmarkTags);
            await m.createTable(savedViews);

            final existingBookmarks = await select(bookmarks).get();
            for (final bookmark in existingBookmarks) {
              for (final name in _normalizeTagNames(bookmark.tags.split(','))) {
                final tagId = await _ensureTag(name);
                await into(bookmarkTags).insert(
                  BookmarkTagsCompanion.insert(
                    bookmarkId: bookmark.id,
                    tagId: tagId,
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
              }
            }
          }

          if (from < 4) {
            await m.addColumn(savedViews, savedViews.tagMatchMode);
            await m.addColumn(savedViews, savedViews.sortField);
            await m.addColumn(savedViews, savedViews.sortDirection);
            await m.createTable(savedViewTags);

            // Preserve v3 saved views that filtered by a single tag.
            final oldViews = await select(savedViews).get();
            for (final view in oldViews) {
              if (view.tagId != null) {
                await into(savedViewTags).insert(
                  SavedViewTagsCompanion.insert(
                    savedViewId: view.id,
                    tagId: view.tagId!,
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
              }
            }
          }
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static List<String> _normalizeTagNames(Iterable<String> names) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in names) {
      final name = raw.trim();
      if (name.isNotEmpty && seen.add(name.toLowerCase())) result.add(name);
    }
    return result;
  }

  Future<int> _ensureTag(String name) async {
    final existing = await (select(tags)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final id = await into(tags).insert(
      TagsCompanion.insert(name: name),
      mode: InsertMode.insertOrIgnore,
    );
    if (id != 0) return id;
    return (await (select(tags)..where((t) => t.name.equals(name))).getSingle())
        .id;
  }

  Future<List<Tag>> _tagsForBookmark(int bookmarkId) {
    final query = select(tags).join([
      innerJoin(bookmarkTags, bookmarkTags.tagId.equalsExp(tags.id)),
    ])
      ..where(bookmarkTags.bookmarkId.equals(bookmarkId))
      ..orderBy([OrderingTerm.asc(tags.name)]);
    return query.map((row) => row.readTable(tags)).get();
  }

  Future<List<Tag>> _tagsForSavedView(int savedViewId) {
    final query = select(tags).join([
      innerJoin(savedViewTags, savedViewTags.tagId.equalsExp(tags.id)),
    ])
      ..where(savedViewTags.savedViewId.equals(savedViewId))
      ..orderBy([OrderingTerm.asc(tags.name)]);
    return query.map((row) => row.readTable(tags)).get();
  }

  Future<BookmarkItem> _toItem(Bookmark bookmark) async => BookmarkItem(
        id: bookmark.id,
        url: bookmark.url,
        title: bookmark.title,
        thumbnail: bookmark.thumbnail,
        description: bookmark.description,
        createdAt: bookmark.createdAt,
        favorite: bookmark.favorite,
        tags: await _tagsForBookmark(bookmark.id),
      );

  Stream<List<BookmarkItem>> watchBookmarkItems() {
    final trigger = customSelect(
      'SELECT b.id FROM bookmarks b LEFT JOIN bookmark_tags bt ON bt.bookmark_id = b.id LEFT JOIN tags t ON t.id = bt.tag_id GROUP BY b.id',
      readsFrom: {bookmarks, bookmarkTags, tags},
    ).watch();

    return trigger.asyncMap((_) async {
      final rows = await select(bookmarks).get();
      return Future.wait(rows.map(_toItem));
    });
  }

  Stream<List<Tag>> watchAllTags() =>
      (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<List<SavedViewConfig>> watchSavedViewConfigs() {
    final trigger = customSelect(
      'SELECT sv.id FROM saved_views sv LEFT JOIN saved_view_tags svt ON svt.saved_view_id = sv.id GROUP BY sv.id',
      readsFrom: {savedViews, savedViewTags, tags},
    ).watch();

    return trigger.asyncMap((_) async {
      final rows = await (select(savedViews)
            ..orderBy([(v) => OrderingTerm.asc(v.createdAt)]))
          .get();
      return Future.wait(rows.map((view) async => SavedViewConfig(
            view: view,
            tags: await _tagsForSavedView(view.id),
          )));
    });
  }

  Future<int> addBookmark({
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
    bool favorite = false,
  }) => transaction(() async {
        final id = await into(bookmarks).insert(
          BookmarksCompanion.insert(
            url: url,
            title: title,
            thumbnail: Value(thumbnail),
            description: Value(description),
            favorite: Value(favorite),
          ),
        );
        await setBookmarkTags(id, tagNames);
        return id;
      });

  Future<void> updateBookmarkFields({
    required int id,
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
  }) => transaction(() async {
        await (update(bookmarks)..where((b) => b.id.equals(id))).write(
          BookmarksCompanion(
            url: Value(url),
            title: Value(title),
            thumbnail: Value(thumbnail),
            description: Value(description),
          ),
        );
        await setBookmarkTags(id, tagNames);
      });

  Future<void> setBookmarkTags(int bookmarkId, Iterable<String> names) async {
    await (delete(bookmarkTags)..where((bt) => bt.bookmarkId.equals(bookmarkId)))
        .go();
    for (final name in _normalizeTagNames(names)) {
      final tagId = await _ensureTag(name);
      await into(bookmarkTags).insert(
        BookmarkTagsCompanion.insert(bookmarkId: bookmarkId, tagId: tagId),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<void> renameTag(int id, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(name: Value(name)),
    );
  }

  Future<void> setTagParent(int id, int? parentTagId) async {
    if (id == parentTagId) return;
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(parentTagId: Value(parentTagId)),
    );
  }

  Future<void> deleteTag(int id) async {
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setFavorite(int id, bool favorite) async {
    await (update(bookmarks)..where((b) => b.id.equals(id))).write(
      BookmarksCompanion(favorite: Value(favorite)),
    );
  }

  Future<int> deleteBookmark(int id) =>
      (delete(bookmarks)..where((b) => b.id.equals(id))).go();

  Future<void> _setSavedViewTags(int viewId, Iterable<int> tagIds) async {
    await (delete(savedViewTags)..where((x) => x.savedViewId.equals(viewId))).go();
    for (final tagId in tagIds.toSet()) {
      await into(savedViewTags).insert(
        SavedViewTagsCompanion.insert(savedViewId: viewId, tagId: tagId),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<int> createSavedView({
    required String name,
    required String layoutType,
    String searchQuery = '',
    bool favoritesOnly = false,
    Iterable<int> tagIds = const [],
    String tagMatchMode = 'or',
    String sortField = 'createdAt',
    String sortDirection = 'desc',
  }) => transaction(() async {
        final id = await into(savedViews).insert(
          SavedViewsCompanion.insert(
            name: name,
            layoutType: Value(layoutType),
            searchQuery: Value(searchQuery),
            favoritesOnly: Value(favoritesOnly),
            tagMatchMode: Value(tagMatchMode),
            sortField: Value(sortField),
            sortDirection: Value(sortDirection),
          ),
        );
        await _setSavedViewTags(id, tagIds);
        return id;
      });

  Future<void> updateSavedView({
    required int id,
    required String name,
    required String layoutType,
    required String searchQuery,
    required bool favoritesOnly,
    required Iterable<int> tagIds,
    required String tagMatchMode,
    required String sortField,
    required String sortDirection,
  }) => transaction(() async {
        await (update(savedViews)..where((v) => v.id.equals(id))).write(
          SavedViewsCompanion(
            name: Value(name),
            layoutType: Value(layoutType),
            searchQuery: Value(searchQuery),
            favoritesOnly: Value(favoritesOnly),
            tagMatchMode: Value(tagMatchMode),
            sortField: Value(sortField),
            sortDirection: Value(sortDirection),
          ),
        );
        await _setSavedViewTags(id, tagIds);
      });

  Future<int> deleteSavedView(int id) =>
      (delete(savedViews)..where((v) => v.id.equals(id))).go();
}
