import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get thumbnail => text().nullable()();
  TextColumn get description => text().nullable()();

  // Legacy column kept so existing databases can be migrated safely.
  // New code uses Tags + BookmarkTags instead.
  TextColumn get tags => text().withDefault(const Constant(''))();

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
  BoolColumn get favoritesOnly =>
      boolean().withDefault(const Constant(false))();
  IntColumn get tagId => integer().nullable().references(
        Tags,
        #id,
        onDelete: KeyAction.setNull,
      )();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
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

@DriftDatabase(tables: [Bookmarks, Tags, BookmarkTags, SavedViews])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'bookmark_app'));

  @override
  int get schemaVersion => 3;

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

            // Convert the old comma-separated tag strings into normalized rows.
            final existingBookmarks = await select(bookmarks).get();
            for (final bookmark in existingBookmarks) {
              final names = _normalizeTagNames(bookmark.tags.split(','));
              for (final name in names) {
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
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static List<String> _normalizeTagNames(Iterable<String> names) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in names) {
      final name = raw.trim();
      if (name.isNotEmpty && seen.add(name.toLowerCase())) {
        result.add(name);
      }
    }
    return result;
  }

  Future<int> _ensureTag(String name) async {
    final existing = await (select(tags)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    return into(tags).insert(
      TagsCompanion.insert(name: name),
      mode: InsertMode.insertOrIgnore,
    ).then((id) async {
      if (id != 0) return id;
      final row = await (select(tags)..where((t) => t.name.equals(name)))
          .getSingle();
      return row.id;
    });
  }

  Future<List<Tag>> _tagsForBookmark(int bookmarkId) {
    final query = select(tags).join([
      innerJoin(bookmarkTags, bookmarkTags.tagId.equalsExp(tags.id)),
    ])
      ..where(bookmarkTags.bookmarkId.equals(bookmarkId))
      ..orderBy([OrderingTerm.asc(tags.name)]);

    return query.map((row) => row.readTable(tags)).get();
  }

  Future<BookmarkItem> _toItem(Bookmark bookmark) async {
    return BookmarkItem(
      id: bookmark.id,
      url: bookmark.url,
      title: bookmark.title,
      thumbnail: bookmark.thumbnail,
      description: bookmark.description,
      createdAt: bookmark.createdAt,
      favorite: bookmark.favorite,
      tags: await _tagsForBookmark(bookmark.id),
    );
  }

  Stream<List<BookmarkItem>> watchBookmarkItems() {
    final trigger = customSelect(
      '''
      SELECT b.id
      FROM bookmarks b
      LEFT JOIN bookmark_tags bt ON bt.bookmark_id = b.id
      LEFT JOIN tags t ON t.id = bt.tag_id
      GROUP BY b.id
      ORDER BY b.created_at DESC
      ''',
      readsFrom: {bookmarks, bookmarkTags, tags},
    ).watch();

    return trigger.asyncMap((_) async {
      final rows = await (select(bookmarks)
            ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]))
          .get();
      return Future.wait(rows.map(_toItem));
    });
  }

  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Stream<List<SavedView>> watchSavedViews() {
    return (select(savedViews)
          ..orderBy([(v) => OrderingTerm.asc(v.createdAt)]))
        .watch();
  }

  Future<int> addBookmark({
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
    bool favorite = false,
  }) {
    return transaction(() async {
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
  }

  Future<void> updateBookmarkFields({
    required int id,
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
  }) {
    return transaction(() async {
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
  }

  Future<void> setBookmarkTags(int bookmarkId, Iterable<String> names) async {
    final normalized = _normalizeTagNames(names);
    await (delete(bookmarkTags)
          ..where((bt) => bt.bookmarkId.equals(bookmarkId)))
        .go();

    for (final name in normalized) {
      final tagId = await _ensureTag(name);
      await into(bookmarkTags).insert(
        BookmarkTagsCompanion.insert(
          bookmarkId: bookmarkId,
          tagId: tagId,
        ),
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

  Future<int> deleteBookmark(int id) {
    return (delete(bookmarks)..where((b) => b.id.equals(id))).go();
  }

  Future<int> createSavedView({
    required String name,
    required String layoutType,
    String searchQuery = '',
    bool favoritesOnly = false,
    int? tagId,
  }) {
    return into(savedViews).insert(
      SavedViewsCompanion.insert(
        name: name,
        layoutType: Value(layoutType),
        searchQuery: Value(searchQuery),
        favoritesOnly: Value(favoritesOnly),
        tagId: Value(tagId),
      ),
    );
  }

  Future<void> updateSavedView({
    required int id,
    required String name,
    required String layoutType,
    required String searchQuery,
    required bool favoritesOnly,
    int? tagId,
  }) async {
    await (update(savedViews)..where((v) => v.id.equals(id))).write(
      SavedViewsCompanion(
        name: Value(name),
        layoutType: Value(layoutType),
        searchQuery: Value(searchQuery),
        favoritesOnly: Value(favoritesOnly),
        tagId: Value(tagId),
      ),
    );
  }

  Future<int> deleteSavedView(int id) {
    return (delete(savedViews)..where((v) => v.id.equals(id))).go();
  }
}
