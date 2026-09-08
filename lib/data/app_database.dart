import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'profile_path_resolver.dart';

part 'app_database.g.dart';
part 'app_database_schema.dart';
part 'app_database_migrations.dart';

@DriftDatabase(
  tables: [
    Bookmarks,
    TagGroups,
    Tags,
    BookmarkTags,
    People,
    BookmarkPeople,
    PersonGroups,
    PersonGroupMembers,
    Photos,
    BookmarkPhotos,
    Collections,
    BookmarkCollections,
    BookmarkRelations,
    SavedViews,
    SavedViewTags,
    Workspaces,
    BookmarkWorkspaces,
    SavedViewWorkspaces,
    WorkspaceSettings,
    DatabaseViews,
    GenericDatabases,
    GenericProperties,
    GenericRecords,
    GenericValues,
    BookmarkAttachments,
    PdfAnnotations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({
    String databaseName = 'bookmark_app',
    this.profileDirectoryPath,
  })  : pathResolver = ProfilePathResolver(profileDirectoryPath),
        super(
          driftDatabase(
            name: databaseName,
            native: profileDirectoryPath == null
                ? null
                : DriftNativeOptions(
                    databasePath: () async =>
                        '$profileDirectoryPath/database.sqlite',
                  ),
          ),
        );

  AppDatabase.forTesting(
    QueryExecutor executor, {
    this.profileDirectoryPath,
  })  : pathResolver = ProfilePathResolver(profileDirectoryPath),
        super(executor);

  final String? profileDirectoryPath;
  final ProfilePathResolver pathResolver;

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await migrateToV2(m);
          if (from < 3) await migrateToV3(m);
          if (from < 4) await migrateToV4(m);
          if (from < 5) await migrateToV5(m);
          if (from < 6) await migrateToV6(m);
          if (from < 7) await migrateToV7(m);
          if (from < 8) await migrateToV8(m);
          if (from < 9) {
            await migrateToV9(m);
          }
          if (from < 10) {
            await migrateToV10(m);
          }
          if (from < 11) {
            await migrateToV11(m);
          }
          if (from < 12) {
            await migrateToV12(m);
          }
          if (from < 13) {
            await migrateToV13(m);
          }
          if (from < 14) {
            await migrateToV14(m);
          }
          if (from < 15) {
            await migrateToV15(m);
          }
          if (from < 16) {
            await migrateToV16(m);
          }
        },
        beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
      );

  static List<String> _normalizeNames(Iterable<String> names) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in names) {
      final name = raw.trim();
      if (name.isNotEmpty && seen.add(name.toLowerCase())) result.add(name);
    }
    return result;
  }

  static String _normalizeNamesText(Iterable<String> names) => _normalizeNames(names).join(', ');

  Future<int> _ensureTag(String name) async {
    final existing = await (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    final id = await into(tags).insert(TagsCompanion.insert(name: name), mode: InsertMode.insertOrIgnore);
    if (id != 0) return id;
    return (await (select(tags)..where((t) => t.name.equals(name))).getSingle()).id;
  }

  Future<int> _ensurePerson(String name) async {
    final existing = await (select(people)..where((p) => p.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    final id = await into(people).insert(PeopleCompanion.insert(name: name), mode: InsertMode.insertOrIgnore);
    if (id != 0) return id;
    return (await (select(people)..where((p) => p.name.equals(name))).getSingle()).id;
  }

  Future<int> _ensureCollection(String name) async {
    final existing = await (select(collections)..where((c) => c.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    final id = await into(collections).insert(CollectionsCompanion.insert(name: name), mode: InsertMode.insertOrIgnore);
    if (id != 0) return id;
    return (await (select(collections)..where((c) => c.name.equals(name))).getSingle()).id;
  }

  Future<List<Tag>> _tagsForBookmark(int bookmarkId) {
    final query = select(tags).join([innerJoin(bookmarkTags, bookmarkTags.tagId.equalsExp(tags.id))])
      ..where(bookmarkTags.bookmarkId.equals(bookmarkId))
      ..orderBy([OrderingTerm.asc(tags.name)]);
    return query.map((row) => row.readTable(tags)).get();
  }

  Stream<List<Tag>> watchAllTags() => (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  Stream<List<Person>> watchAllPeople() => (select(people)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();
  Stream<List<CollectionRecord>> watchAllCollections() =>
      (select(collections)..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();
  Stream<List<BookmarkRelation>> watchRelationsForBookmark(int bookmarkId) =>
      (select(bookmarkRelations)
            ..where((r) => r.sourceBookmarkId.equals(bookmarkId) | r.targetBookmarkId.equals(bookmarkId)))
          .watch();

  Future<int> addBookmark({
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
    Iterable<String> personNames = const [],
    bool favorite = false,
    String status = 'unread',
    int rating = 0,
  }) => transaction(() async {
        final readingStatus = status == 'archived' ? 'unread' : status;
        final storageState = status == 'archived' ? 'archived' : 'active';
        final id = await into(bookmarks).insert(BookmarksCompanion.insert(
          url: url,
          title: title,
          thumbnail: Value(thumbnail),
          description: Value(description),
          favorite: Value(favorite),
          status: Value(status),
          readingStatus: Value(readingStatus),
          storageState: Value(storageState),
          rating: Value(rating.clamp(0, 5)),
        ));
        await setBookmarkTags(id, tagNames);
        await setBookmarkPeople(id, personNames);
        return id;
      });

  Future<void> updateBookmarkFields({
    required int id,
    required String url,
    required String title,
    String? thumbnail,
    String? description,
    Iterable<String> tagNames = const [],
    String? status,
    int? rating,
  }) => transaction(() async {
        final readingStatus = status == null
            ? const Value<String>.absent()
            : Value(status == 'archived' ? 'unread' : status);
        final storageState = status == 'archived'
            ? const Value('archived')
            : const Value<String>.absent();
        await (update(bookmarks)..where((b) => b.id.equals(id))).write(BookmarksCompanion(
          url: Value(url),
          title: Value(title),
          thumbnail: Value(thumbnail),
          description: Value(description),
          status: status == null ? const Value.absent() : Value(status),
          readingStatus: readingStatus,
          storageState: storageState,
          rating: rating == null ? const Value.absent() : Value(rating.clamp(0, 5)),
        ));
        await setBookmarkTags(id, tagNames);
      });

  Future<void> setBookmarkTags(int bookmarkId, Iterable<String> names) async {
    await (delete(bookmarkTags)..where((bt) => bt.bookmarkId.equals(bookmarkId))).go();
    for (final name in _normalizeNames(names)) {
      final tagId = await _ensureTag(name);
      await into(bookmarkTags).insert(
        BookmarkTagsCompanion.insert(bookmarkId: bookmarkId, tagId: tagId), mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<void> setBookmarkPeople(int bookmarkId, Iterable<String> names) async {
    await (delete(bookmarkPeople)..where((bp) => bp.bookmarkId.equals(bookmarkId))).go();
    for (final name in _normalizeNames(names)) {
      final personId = await _ensurePerson(name);
      await into(bookmarkPeople).insert(
        BookmarkPeopleCompanion.insert(
          bookmarkId: bookmarkId,
          personId: personId,
          role: const Value('出演者'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<void> setBookmarkCollections(int bookmarkId, Iterable<String> names) async {
    await (delete(bookmarkCollections)..where((bc) => bc.bookmarkId.equals(bookmarkId))).go();
    for (final name in _normalizeNames(names)) {
      final collectionId = await _ensureCollection(name);
      await into(bookmarkCollections).insert(
        BookmarkCollectionsCompanion.insert(bookmarkId: bookmarkId, collectionId: collectionId),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<void> addTagsToBookmarks(Iterable<int> bookmarkIds, Iterable<String> names) => transaction(() async {
        for (final bookmarkId in bookmarkIds.toSet()) {
          final current = await _tagsForBookmark(bookmarkId);
          await setBookmarkTags(bookmarkId, [...current.map((e) => e.name), ...names]);
        }
      });

  Future<void> removeTagsFromBookmarks(Iterable<int> bookmarkIds, Iterable<String> names) => transaction(() async {
        final removing = _normalizeNames(names).map((e) => e.toLowerCase()).toSet();
        for (final bookmarkId in bookmarkIds.toSet()) {
          final current = await _tagsForBookmark(bookmarkId);
          await setBookmarkTags(bookmarkId, current.map((e) => e.name).where((e) => !removing.contains(e.toLowerCase())));
        }
      });

  Future<int> addPhoto({required String path, String? title, String? note, Iterable<String> tagNames = const []}) =>
      into(photos).insert(PhotosCompanion.insert(path: pathResolver.toStoredPath(path), title: Value(title), note: Value(note), tags: Value(_normalizeNamesText(tagNames))));

  Future<void> deletePhoto(int id) => transaction(() async {
        await (update(people)..where((person) => person.profilePhotoId.equals(id)))
            .write(const PeopleCompanion(profilePhotoId: Value(null)));
        await (delete(photos)..where((photo) => photo.id.equals(id))).go();
      });

  Future<int> createPerson(String name, {String? note}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Person name is empty');
    final id = await _ensurePerson(trimmed);
    if (note != null && note.trim().isNotEmpty) {
      await (update(people)..where((p) => p.id.equals(id))).write(PeopleCompanion(note: Value(note.trim())));
    }
    return id;
  }

  Future<void> updatePerson(int id, String name, String? note) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await (update(people)..where((p) => p.id.equals(id))).write(PeopleCompanion(
      name: Value(trimmed),
      note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
    ));
  }
  Future<void> deletePerson(int id) => (delete(people)..where((p) => p.id.equals(id))).go();

  Future<int> createCollection(String name, {String? note}) async {
    final id = await _ensureCollection(name.trim());
    if (note?.trim().isNotEmpty == true) {
      await (update(collections)..where((c) => c.id.equals(id))).write(CollectionsCompanion(note: Value(note!.trim())));
    }
    return id;
  }
  Future<void> deleteCollection(int id) => (delete(collections)..where((c) => c.id.equals(id))).go();

  Future<void> addBookmarkRelation(int sourceId, int targetId, String type) async {
    if (sourceId == targetId) return;
    await into(bookmarkRelations).insert(
      BookmarkRelationsCompanion.insert(sourceBookmarkId: sourceId, targetBookmarkId: targetId, relationType: Value(type)),
      mode: InsertMode.insertOrIgnore,
    );
  }
  Future<void> removeBookmarkRelation(int sourceId, int targetId, String type) =>
      (delete(bookmarkRelations)..where((r) =>
          r.sourceBookmarkId.equals(sourceId) & r.targetBookmarkId.equals(targetId) & r.relationType.equals(type))).go();

  Future<int> createTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Tag name is empty');
    return _ensureTag(trimmed);
  }

  Future<int> deleteBookmark(int id) => (delete(bookmarks)..where((b) => b.id.equals(id))).go();
}
