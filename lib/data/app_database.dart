import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get thumbnail => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [Bookmarks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'bookmark_app'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(bookmarks, bookmarks.tags);
          }
        },
      );

  Future<int> addBookmark({
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    String tags = '',
    bool favorite = false,
  }) {
    return into(bookmarks).insert(
      BookmarksCompanion.insert(
        url: url,
        title: title,
        thumbnail: Value(thumbnail),
        description: Value(description),
        tags: Value(tags),
        favorite: Value(favorite),
      ),
    );
  }

  Stream<List<Bookmark>> watchAllBookmarks() {
    return (select(bookmarks)
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .watch();
  }

  Stream<List<Bookmark>> watchFavorites() {
    return (select(bookmarks)
          ..where((row) => row.favorite.equals(true))
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .watch();
  }

  Future<Bookmark?> getBookmarkById(int id) {
    return (select(bookmarks)..where((row) => row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> updateBookmarkFields({
    required int id,
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    String tags = '',
  }) async {
    await (update(bookmarks)..where((row) => row.id.equals(id))).write(
      BookmarksCompanion(
        url: Value(url),
        title: Value(title),
        thumbnail: Value(thumbnail),
        description: Value(description),
        tags: Value(tags),
      ),
    );
  }

  Future<void> setFavorite(int id, bool favorite) async {
    await (update(bookmarks)..where((row) => row.id.equals(id))).write(
      BookmarksCompanion(favorite: Value(favorite)),
    );
  }

  Future<void> updateThumbnail(int id, String? thumbnail) async {
    await (update(bookmarks)..where((row) => row.id.equals(id))).write(
      BookmarksCompanion(thumbnail: Value(thumbnail)),
    );
  }

  Future<int> deleteBookmark(int id) {
    return (delete(bookmarks)..where((row) => row.id.equals(id))).go();
  }
}
