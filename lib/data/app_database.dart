import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  }) : super(driftDatabase(name: databaseName));

  AppDatabase.forTesting(
    QueryExecutor executor, {
    this.profileDirectoryPath,
  }) : super(executor);

  final String? profileDirectoryPath;

  String resolveStoredPath(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) {
      return path;
    }
    final root = profileDirectoryPath
        ?.replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+$'), '');
    if (root == null || root.isEmpty) return path;
    return '$root/${path.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '')}';
  }

  String toStoredPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final root = profileDirectoryPath
        ?.replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+$'), '');
    if (root == null || root.isEmpty) return normalized;
    if (normalized == root) return '.';
    final prefix = '$root/';
    return normalized.startsWith(prefix)
        ? normalized.substring(prefix.length)
        : normalized;
  }

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(bookmarks, bookmarks.tags);
          if (from < 3) {
            await m.createTable(tags);
            await m.createTable(bookmarkTags);
            await m.createTable(savedViews);
            final existingBookmarks = await select(bookmarks).get();
            for (final bookmark in existingBookmarks) {
              for (final name in _normalizeNames(bookmark.tags.split(','))) {
                final tagId = await _ensureTag(name);
                await into(bookmarkTags).insert(
                  BookmarkTagsCompanion.insert(bookmarkId: bookmark.id, tagId: tagId),
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
            final oldViews = await select(savedViews).get();
            for (final view in oldViews) {
              if (view.tagId != null) {
                await into(savedViewTags).insert(
                  SavedViewTagsCompanion.insert(savedViewId: view.id, tagId: view.tagId!),
                  mode: InsertMode.insertOrIgnore,
                );
              }
            }
          }
          if (from < 5) {
            await m.createTable(people);
            await m.createTable(bookmarkPeople);
          }
          if (from < 6) {
            await m.createTable(photos);
            await m.createTable(bookmarkPhotos);
          }
          if (from < 7) await m.addColumn(photos, photos.tags);
          if (from < 8) await m.addColumn(savedViews, savedViews.visibleProperties);
          if (from < 9) {
            await m.addColumn(bookmarks, bookmarks.status);
            await m.addColumn(bookmarks, bookmarks.rating);
            await m.addColumn(bookmarks, bookmarks.lastOpenedAt);
            await m.addColumn(bookmarks, bookmarks.openCount);
            await m.addColumn(people, people.profilePhotoId);
            await m.addColumn(savedViews, savedViews.statusFilter);
            await m.addColumn(savedViews, savedViews.minRating);
            await m.createTable(collections);
            await m.createTable(bookmarkCollections);
            await m.createTable(bookmarkRelations);
          }
          if (from < 10) {
            await customStatement('ALTER TABLE bookmark_people RENAME TO bookmark_people_old');
            await customStatement(
              "CREATE TABLE bookmark_people ("
              "bookmark_id INTEGER NOT NULL REFERENCES bookmarks(id) ON DELETE CASCADE, "
              "person_id INTEGER NOT NULL REFERENCES people(id) ON DELETE CASCADE, "
              "role TEXT NOT NULL DEFAULT '出演者', "
              "PRIMARY KEY (bookmark_id, person_id, role))",
            );
            await customStatement(
              "INSERT OR IGNORE INTO bookmark_people (bookmark_id, person_id, role) "
              "SELECT bookmark_id, person_id, CASE WHEN role = '出演' OR role = 'performer' THEN '出演者' ELSE role END "
              "FROM bookmark_people_old",
            );
            await customStatement('DROP TABLE bookmark_people_old');
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

  Future<List<Person>> _peopleForBookmark(int bookmarkId) {
    final query = select(people).join([innerJoin(bookmarkPeople, bookmarkPeople.personId.equalsExp(people.id))])
      ..where(bookmarkPeople.bookmarkId.equals(bookmarkId))
      ..orderBy([OrderingTerm.asc(people.name)]);
    return query.map((row) => row.readTable(people)).get();
  }

  Future<List<Tag>> _tagsForSavedView(int savedViewId) {
    final query = select(tags).join([innerJoin(savedViewTags, savedViewTags.tagId.equalsExp(tags.id))])
      ..where(savedViewTags.savedViewId.equals(savedViewId))
      ..orderBy([OrderingTerm.asc(tags.name)]);
    return query.map((row) => row.readTable(tags)).get();
  }

  Stream<List<BookmarkItem>> watchBookmarkItems() {
    final trigger = customSelect(
      'SELECT b.id FROM bookmarks b '
      'LEFT JOIN bookmark_tags bt ON bt.bookmark_id = b.id '
      'LEFT JOIN bookmark_people bp ON bp.bookmark_id = b.id '
      'LEFT JOIN bookmark_photos bph ON bph.bookmark_id = b.id '
      'LEFT JOIN bookmark_collections bc ON bc.bookmark_id = b.id '
      'GROUP BY b.id',
      readsFrom: {
        bookmarks,
        bookmarkTags,
        tags,
        bookmarkPeople,
        people,
        bookmarkPhotos,
        photos,
        bookmarkCollections,
        collections,
      },
    ).watch();

    return trigger.asyncMap((_) async {
      final bookmarkRows = await select(bookmarks).get();
      final tagsByBookmark = <int, List<Tag>>{};
      final peopleByBookmark = <int, Map<int, Person>>{};
      final photosByBookmark = <int, List<PhotoRecord>>{};
      final coverByBookmark = <int, PhotoRecord>{};
      final collectionsByBookmark = <int, List<CollectionRecord>>{};

      final tagRows = await select(bookmarkTags).join([
        innerJoin(tags, tags.id.equalsExp(bookmarkTags.tagId)),
      ]).get();
      for (final row in tagRows) {
        final relation = row.readTable(bookmarkTags);
        tagsByBookmark
            .putIfAbsent(relation.bookmarkId, () => <Tag>[])
            .add(row.readTable(tags));
      }

      final peopleRows = await select(bookmarkPeople).join([
        innerJoin(people, people.id.equalsExp(bookmarkPeople.personId)),
      ]).get();
      for (final row in peopleRows) {
        final relation = row.readTable(bookmarkPeople);
        final person = row.readTable(people);
        peopleByBookmark
            .putIfAbsent(relation.bookmarkId, () => <int, Person>{})[person.id] =
            person;
      }

      final photoRows = await select(bookmarkPhotos).join([
        innerJoin(photos, photos.id.equalsExp(bookmarkPhotos.photoId)),
      ]).get();
      for (final row in photoRows) {
        final relation = row.readTable(bookmarkPhotos);
        final photo = _resolvedPhoto(row.readTable(photos));
        photosByBookmark
            .putIfAbsent(relation.bookmarkId, () => <PhotoRecord>[])
            .add(photo);
        if (relation.isCover) coverByBookmark[relation.bookmarkId] = photo;
      }

      final collectionRows = await select(bookmarkCollections).join([
        innerJoin(
          collections,
          collections.id.equalsExp(bookmarkCollections.collectionId),
        ),
      ]).get();
      for (final row in collectionRows) {
        final relation = row.readTable(bookmarkCollections);
        collectionsByBookmark
            .putIfAbsent(relation.bookmarkId, () => <CollectionRecord>[])
            .add(row.readTable(collections));
      }

      for (final values in tagsByBookmark.values) {
        values.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
      for (final values in photosByBookmark.values) {
        values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      for (final values in collectionsByBookmark.values) {
        values.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }

      return bookmarkRows
          .map(
            (bookmark) => BookmarkItem(
              id: bookmark.id,
              url: bookmark.url,
              title: bookmark.title,
              thumbnail: bookmark.thumbnail,
              description: bookmark.description,
              createdAt: bookmark.createdAt,
              favorite: bookmark.favorite,
              status: bookmark.status,
              readingStatus: bookmark.readingStatus,
              storageState: bookmark.storageState,
              genre: bookmark.genre,
              deletedAt: bookmark.deletedAt,
              rating: bookmark.rating,
              lastOpenedAt: bookmark.lastOpenedAt,
              openCount: bookmark.openCount,
              tags: tagsByBookmark[bookmark.id] ?? const [],
              people: (peopleByBookmark[bookmark.id]?.values.toList() ?? <Person>[])
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                ),
              photos: photosByBookmark[bookmark.id] ?? const [],
              collections: collectionsByBookmark[bookmark.id] ?? const [],
              coverPhoto: coverByBookmark[bookmark.id],
            ),
          )
          .toList();
    });
  }

  Stream<List<Tag>> watchAllTags() => (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  Stream<List<Person>> watchAllPeople() => (select(people)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();
  Stream<List<PhotoRecord>> watchAllPhotos() =>
      (select(photos)..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
          .watch()
          .map((rows) => rows.map(_resolvedPhoto).toList());
  Stream<List<CollectionRecord>> watchAllCollections() =>
      (select(collections)..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();
  Stream<List<BookmarkRelation>> watchRelationsForBookmark(int bookmarkId) =>
      (select(bookmarkRelations)
            ..where((r) => r.sourceBookmarkId.equals(bookmarkId) | r.targetBookmarkId.equals(bookmarkId)))
          .watch();

  Stream<List<SavedViewConfig>> watchSavedViewConfigs() {
    final trigger = customSelect(
      'SELECT sv.id FROM saved_views sv LEFT JOIN saved_view_tags svt ON svt.saved_view_id = sv.id GROUP BY sv.id',
      readsFrom: {savedViews, savedViewTags, tags},
    ).watch();
    return trigger.asyncMap((_) async {
      final rows = await (select(savedViews)..orderBy([(v) => OrderingTerm.asc(v.createdAt)])).get();
      return Future.wait(rows.map((view) async => SavedViewConfig(view: view, tags: await _tagsForSavedView(view.id))));
    });
  }

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
    Iterable<String>? personNames,
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
        if (personNames != null) await setBookmarkPeople(id, personNames);
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

  Future<void> addPeopleToBookmarks(Iterable<int> bookmarkIds, Iterable<String> names) => transaction(() async {
        for (final bookmarkId in bookmarkIds.toSet()) {
          final current = await _peopleForBookmark(bookmarkId);
          await setBookmarkPeople(bookmarkId, [...current.map((e) => e.name), ...names]);
        }
      });

  Future<void> removePeopleFromBookmarks(Iterable<int> bookmarkIds, Iterable<String> names) => transaction(() async {
        final removing = _normalizeNames(names).map((e) => e.toLowerCase()).toSet();
        for (final bookmarkId in bookmarkIds.toSet()) {
          final current = await _peopleForBookmark(bookmarkId);
          await setBookmarkPeople(bookmarkId, current.map((e) => e.name).where((e) => !removing.contains(e.toLowerCase())));
        }
      });

  Future<void> batchSetStatus(Iterable<int> ids, String status) async {
    final readingStatus = status == 'archived' ? 'unread' : status;
    for (final id in ids.toSet()) {
      await (update(bookmarks)..where((b) => b.id.equals(id))).write(BookmarksCompanion(
        status: Value(status),
        readingStatus: Value(readingStatus),
        storageState: status == 'archived' ? const Value('archived') : const Value.absent(),
      ));
    }
  }

  Future<void> batchSetRating(Iterable<int> ids, int rating) async {
    for (final id in ids.toSet()) {
      await (update(bookmarks)..where((b) => b.id.equals(id))).write(BookmarksCompanion(rating: Value(rating.clamp(0, 5))));
    }
  }

  Future<void> batchSetFavorite(Iterable<int> ids, bool favorite) async {
    for (final id in ids.toSet()) {
      await (update(bookmarks)..where((b) => b.id.equals(id))).write(BookmarksCompanion(favorite: Value(favorite)));
    }
  }

  Future<void> recordBookmarkOpen(int id) async {
    final bookmark = await (select(bookmarks)..where((b) => b.id.equals(id))).getSingleOrNull();
    if (bookmark == null) return;
    await (update(bookmarks)..where((b) => b.id.equals(id))).write(BookmarksCompanion(
      lastOpenedAt: Value(DateTime.now()),
      openCount: Value(bookmark.openCount + 1),
    ));
  }

  Future<int> addPhoto({required String path, String? title, String? note, Iterable<String> tagNames = const []}) =>
      into(photos).insert(PhotosCompanion.insert(path: toStoredPath(path), title: Value(title), note: Value(note), tags: Value(_normalizeNamesText(tagNames))));

  Future<void> updatePhoto(int id, {String? title, String? note, Iterable<String>? tagNames}) =>
      (update(photos)..where((p) => p.id.equals(id))).write(PhotosCompanion(
        title: Value(title), note: Value(note),
        tags: tagNames == null ? const Value.absent() : Value(_normalizeNamesText(tagNames)),
      ));

  Future<void> deletePhoto(int id) => transaction(() async {
        await (update(people)..where((person) => person.profilePhotoId.equals(id)))
            .write(const PeopleCompanion(profilePhotoId: Value(null)));
        await (delete(photos)..where((photo) => photo.id.equals(id))).go();
      });

  Future<void> attachPhotoToBookmark(int bookmarkId, int photoId, {bool asCover = false}) => transaction(() async {
        if (asCover) {
          await (update(bookmarkPhotos)..where((bp) => bp.bookmarkId.equals(bookmarkId)))
              .write(const BookmarkPhotosCompanion(isCover: Value(false)));
        }
        await into(bookmarkPhotos).insert(
          BookmarkPhotosCompanion.insert(bookmarkId: bookmarkId, photoId: photoId, isCover: Value(asCover)),
          mode: InsertMode.insertOrReplace,
        );
      });

  Future<void> attachPhotosToBookmark(int bookmarkId, Iterable<int> photoIds, {int? coverPhotoId}) => transaction(() async {
        final uniqueIds = photoIds.toSet();
        if (coverPhotoId != null) uniqueIds.add(coverPhotoId);
        if (coverPhotoId != null) {
          await (update(bookmarkPhotos)..where((bp) => bp.bookmarkId.equals(bookmarkId)))
              .write(const BookmarkPhotosCompanion(isCover: Value(false)));
        }
        for (final photoId in uniqueIds) {
          await into(bookmarkPhotos).insert(
            BookmarkPhotosCompanion.insert(bookmarkId: bookmarkId, photoId: photoId, isCover: Value(photoId == coverPhotoId)),
            mode: InsertMode.insertOrReplace,
          );
        }
      });

  Future<void> detachPhotoFromBookmark(int bookmarkId, int photoId) =>
      (delete(bookmarkPhotos)..where((bp) => bp.bookmarkId.equals(bookmarkId) & bp.photoId.equals(photoId))).go();

  Future<void> setCoverPhoto(int bookmarkId, int photoId) => transaction(() async {
        await (update(bookmarkPhotos)..where((bp) => bp.bookmarkId.equals(bookmarkId)))
            .write(const BookmarkPhotosCompanion(isCover: Value(false)));
        await into(bookmarkPhotos).insert(
          BookmarkPhotosCompanion.insert(bookmarkId: bookmarkId, photoId: photoId, isCover: const Value(true)),
          mode: InsertMode.insertOrReplace,
        );
      });

  Future<void> clearCoverPhoto(int bookmarkId) =>
      (update(bookmarkPhotos)..where((bp) => bp.bookmarkId.equals(bookmarkId)))
          .write(const BookmarkPhotosCompanion(isCover: Value(false)));

  Future<int> createPerson(String name, {String? note}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Person name is empty');
    final id = await _ensurePerson(trimmed);
    if (note != null && note.trim().isNotEmpty) {
      await (update(people)..where((p) => p.id.equals(id))).write(PeopleCompanion(note: Value(note.trim())));
    }
    return id;
  }

  Future<void> updatePerson(int id, String name, String? note, {int? profilePhotoId, bool updateProfilePhoto = false}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await (update(people)..where((p) => p.id.equals(id))).write(PeopleCompanion(
      name: Value(trimmed),
      note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
      profilePhotoId: updateProfilePhoto ? Value(profilePhotoId) : const Value.absent(),
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

  Future<int> createTag(String name, {int? parentTagId}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Tag name is empty');
    final id = await _ensureTag(trimmed);
    if (parentTagId != null) await setTagParent(id, parentTagId);
    return id;
  }
  Future<void> renameTag(int id, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    await (update(tags)..where((t) => t.id.equals(id))).write(TagsCompanion(name: Value(name)));
  }
  Future<bool> _wouldCreateTagCycle(int id, int? parentTagId) async {
    var current = parentTagId;
    final visited = <int>{id};
    while (current != null) {
      if (!visited.add(current)) return true;
      final row = await (select(tags)..where((t) => t.id.equals(current!))).getSingleOrNull();
      current = row?.parentTagId;
    }
    return false;
  }
  Future<void> setTagParent(int id, int? parentTagId) async {
    if (id == parentTagId) throw ArgumentError('A tag cannot be its own parent');
    if (await _wouldCreateTagCycle(id, parentTagId)) throw ArgumentError('This parent would create a tag cycle');
    await (update(tags)..where((t) => t.id.equals(id))).write(TagsCompanion(parentTagId: Value(parentTagId)));
  }
  Future<void> deleteTag(int id) async {
    await transaction(() async {
      await (update(tags)..where((t) => t.parentTagId.equals(id))).write(const TagsCompanion(parentTagId: Value(null)));
      await (delete(tags)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> setFavorite(int id, bool favorite) async {
    await (update(bookmarks)..where((b) => b.id.equals(id))).write(BookmarksCompanion(favorite: Value(favorite)));
  }

  Future<void> setStatus(int id, String status) async {
    await (update(bookmarks)..where((b) => b.id.equals(id))).write(BookmarksCompanion(
      status: Value(status),
      readingStatus: Value(status == 'archived' ? 'unread' : status),
      storageState: status == 'archived' ? const Value('archived') : const Value.absent(),
    ));
  }

  Future<void> setGenre(int id, String genre) =>
      (update(bookmarks)..where((b) => b.id.equals(id))).write(
        BookmarksCompanion(genre: Value(genre.trim())),
      );

  Future<void> setRating(int id, int rating) =>
      (update(bookmarks)..where((b) => b.id.equals(id))).write(BookmarksCompanion(rating: Value(rating.clamp(0, 5))));
  Future<int> deleteBookmark(int id) => (delete(bookmarks)..where((b) => b.id.equals(id))).go();

  Future<void> _setSavedViewTags(int viewId, Iterable<int> tagIds) async {
    await (delete(savedViewTags)..where((x) => x.savedViewId.equals(viewId))).go();
    for (final tagId in tagIds.toSet()) {
      await into(savedViewTags).insert(
        SavedViewTagsCompanion.insert(savedViewId: viewId, tagId: tagId), mode: InsertMode.insertOrIgnore,
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
    String visibleProperties = 'image,url,tags,favorite',
    String statusFilter = '',
    int minRating = 0,
    bool includeDescendants = true,
    int? personFilterId,
    int? photoFilterId,
  }) => transaction(() async {
        final id = await into(savedViews).insert(SavedViewsCompanion.insert(
          name: name,
          layoutType: Value(layoutType),
          searchQuery: Value(searchQuery),
          favoritesOnly: Value(favoritesOnly),
          tagMatchMode: Value(tagMatchMode),
          sortField: Value(sortField),
          sortDirection: Value(sortDirection),
          visibleProperties: Value(visibleProperties),
          statusFilter: Value(statusFilter),
          minRating: Value(minRating.clamp(0, 5)),
          includeDescendants: Value(includeDescendants),
          personFilterId: Value(personFilterId),
          photoFilterId: Value(photoFilterId),
        ));
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
    required String visibleProperties,
    required String statusFilter,
    required int minRating,
    required bool includeDescendants,
    int? personFilterId,
    int? photoFilterId,
  }) => transaction(() async {
        await (update(savedViews)..where((v) => v.id.equals(id))).write(SavedViewsCompanion(
          name: Value(name), layoutType: Value(layoutType), searchQuery: Value(searchQuery),
          favoritesOnly: Value(favoritesOnly), tagMatchMode: Value(tagMatchMode),
          sortField: Value(sortField), sortDirection: Value(sortDirection), visibleProperties: Value(visibleProperties),
          statusFilter: Value(statusFilter), minRating: Value(minRating.clamp(0, 5)),
          includeDescendants: Value(includeDescendants),
          personFilterId: Value(personFilterId),
          photoFilterId: Value(photoFilterId),
        ));
        await _setSavedViewTags(id, tagIds);
      });

  PhotoRecord _resolvedPhoto(PhotoRecord photo) => PhotoRecord(
        id: photo.id,
        path: resolveStoredPath(photo.path),
        title: photo.title,
        note: photo.note,
        tags: photo.tags,
        createdAt: photo.createdAt,
      );


  Future<int> deleteSavedView(int id) => (delete(savedViews)..where((v) => v.id.equals(id))).go();
}
