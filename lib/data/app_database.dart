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

  /// Legacy status column kept during the v11 transition.
  TextColumn get status => text().withDefault(const Constant('unread'))();

  /// Reading / viewing progress, independent from where the bookmark is stored.
  TextColumn get readingStatus => text().withDefault(const Constant('unread'))();

  /// active / inbox / archived / trash.
  TextColumn get storageState => text().withDefault(const Constant('active'))();

  /// First-class genre value. Legacy genre_state remains readable during migration.
  TextColumn get genre => text().withDefault(const Constant(''))();

  /// Timestamp for trash retention / future automatic cleanup.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get rating => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  IntColumn get openCount => integer().withDefault(const Constant(0))();
}

@DataClassName('TagGroupRecord')
class TagGroups extends Table {
  @override
  String get tableName => 'tag_groups';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get parentTagId => integer().nullable()();
  IntColumn get groupId => integer().nullable().references(TagGroups, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class BookmarkTags extends Table {
  IntColumn get bookmarkId => integer().references(Bookmarks, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column<Object>> get primaryKey => {bookmarkId, tagId};
}

@DataClassName('Person')
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get note => text().nullable()();
  IntColumn get profilePhotoId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class BookmarkPeople extends Table {
  IntColumn get bookmarkId => integer().references(Bookmarks, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(People, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text().withDefault(const Constant('出演者'))();
  @override
  Set<Column<Object>> get primaryKey => {bookmarkId, personId, role};
}

@DataClassName('PhotoRecord')
class Photos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class BookmarkPhotos extends Table {
  IntColumn get bookmarkId => integer().references(Bookmarks, #id, onDelete: KeyAction.cascade)();
  IntColumn get photoId => integer().references(Photos, #id, onDelete: KeyAction.cascade)();
  BoolColumn get isCover => boolean().withDefault(const Constant(false))();
  @override
  Set<Column<Object>> get primaryKey => {bookmarkId, photoId};
}

@DataClassName('CollectionRecord')
class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class BookmarkCollections extends Table {
  IntColumn get bookmarkId => integer().references(Bookmarks, #id, onDelete: KeyAction.cascade)();
  IntColumn get collectionId => integer().references(Collections, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column<Object>> get primaryKey => {bookmarkId, collectionId};
}

class BookmarkRelations extends Table {
  @ReferenceName('outgoingBookmarkRelations')
  IntColumn get sourceBookmarkId => integer().references(Bookmarks, #id, onDelete: KeyAction.cascade)();

  @ReferenceName('incomingBookmarkRelations')
  IntColumn get targetBookmarkId => integer().references(Bookmarks, #id, onDelete: KeyAction.cascade)();

  TextColumn get relationType => text().withDefault(const Constant('related'))();
  @override
  Set<Column<Object>> get primaryKey => {sourceBookmarkId, targetBookmarkId, relationType};
}

class SavedViews extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get layoutType => text().withDefault(const Constant('gallery'))();
  TextColumn get searchQuery => text().withDefault(const Constant(''))();
  BoolColumn get favoritesOnly => boolean().withDefault(const Constant(false))();
  IntColumn get tagId => integer().nullable().references(Tags, #id, onDelete: KeyAction.setNull)();
  TextColumn get tagMatchMode => text().withDefault(const Constant('or'))();
  TextColumn get sortField => text().withDefault(const Constant('createdAt'))();
  TextColumn get sortDirection => text().withDefault(const Constant('desc'))();
  TextColumn get visibleProperties => text().withDefault(const Constant('image,url,tags,favorite'))();
  TextColumn get statusFilter => text().withDefault(const Constant(''))();
  IntColumn get minRating => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SavedViewTags extends Table {
  IntColumn get savedViewId => integer().references(SavedViews, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column<Object>> get primaryKey => {savedViewId, tagId};
}

@DataClassName('WorkspaceRecord')
class Workspaces extends Table {
  @override
  String get tableName => 'workspaces';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get createdAt => text().withDefault(const CustomExpression<String>('CURRENT_TIMESTAMP'))();
  TextColumn get icon => text().withDefault(const Constant('📁'))();
  IntColumn get colorValue => integer().withDefault(const Constant(4288585374))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class BookmarkWorkspaces extends Table {
  @override
  String get tableName => 'bookmark_workspace';

  IntColumn get bookmarkId => integer().references(Bookmarks, #id, onDelete: KeyAction.cascade)();
  IntColumn get workspaceId => integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {bookmarkId};
}

class SavedViewWorkspaces extends Table {
  @override
  String get tableName => 'saved_view_workspace';

  IntColumn get savedViewId => integer().references(SavedViews, #id, onDelete: KeyAction.cascade)();
  IntColumn get workspaceId => integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {savedViewId};
}

class WorkspaceSettings extends Table {
  @override
  String get tableName => 'workspace_settings';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('BookmarkAttachmentRecord')
class BookmarkAttachments extends Table {
  @override
  String get tableName => 'bookmark_attachments';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookmarkId => integer().references(Bookmarks, #id, onDelete: KeyAction.cascade)();
  TextColumn get fileName => text()();
  TextColumn get path => text().unique()();
  TextColumn get kind => text().withDefault(const Constant('file'))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text()();
}

@DataClassName('PdfAnnotationRow')
class PdfAnnotations extends Table {
  @override
  String get tableName => 'pdf_annotations';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get attachmentId => integer().references(BookmarkAttachments, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageNumber => integer()();
  TextColumn get kind => text().withDefault(const Constant('note'))();
  TextColumn get selectedText => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text()();
}

class BookmarkItem {
  const BookmarkItem({
    required this.id,
    required this.url,
    required this.title,
    required this.createdAt,
    required this.favorite,
    required this.status,
    required this.rating,
    required this.openCount,
    required this.tags,
    required this.people,
    required this.photos,
    required this.collections,
    this.readingStatus = 'unread',
    this.storageState = 'active',
    this.genre = '',
    this.deletedAt,
    this.coverPhoto,
    this.thumbnail,
    this.description,
    this.lastOpenedAt,
  });

  final int id;
  final String url;
  final String title;
  final String? thumbnail;
  final String? description;
  final DateTime createdAt;
  final bool favorite;

  /// Legacy compatibility status. New code should prefer readingStatus/storageState.
  final String status;
  final String readingStatus;
  final String storageState;
  final String genre;
  final DateTime? deletedAt;

  final int rating;
  final DateTime? lastOpenedAt;
  final int openCount;
  final List<Tag> tags;
  final List<Person> people;
  final List<PhotoRecord> photos;
  final List<CollectionRecord> collections;
  final PhotoRecord? coverPhoto;
}

class SavedViewConfig {
  const SavedViewConfig({required this.view, required this.tags});
  final SavedView view;
  final List<Tag> tags;
}

@DriftDatabase(
  tables: [
    Bookmarks,
    TagGroups,
    Tags,
    BookmarkTags,
    People,
    BookmarkPeople,
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
    if (path.isEmpty || path.startsWith('/') || RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) {
      return path;
    }
    final root = profileDirectoryPath?.replaceAll('\\', '/').replaceAll(RegExp(r'/+

  @override
  int get schemaVersion => 13;

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
            final info = await customSelect('PRAGMA table_info(bookmarks)').get();
            final names = info.map((row) => row.read<String>('name')).toSet();

            if (!names.contains('reading_status')) {
              await m.addColumn(bookmarks, bookmarks.readingStatus);
            }
            if (!names.contains('storage_state')) {
              await m.addColumn(bookmarks, bookmarks.storageState);
            }
            if (!names.contains('genre')) {
              await m.addColumn(bookmarks, bookmarks.genre);
            }
            if (!names.contains('deleted_at')) {
              await m.addColumn(bookmarks, bookmarks.deletedAt);
            }

            await customStatement('''
              UPDATE bookmarks
              SET reading_status = CASE
                    WHEN status IN ('unread', 'later', 'in_progress', 'done') THEN status
                    ELSE 'unread'
                  END,
                  storage_state = CASE
                    WHEN status = 'archived' THEN 'archived'
                    ELSE storage_state
                  END
            ''');

            if (names.contains('inbox_state')) {
              await customStatement('''
                UPDATE bookmarks
                SET storage_state = 'inbox'
                WHERE inbox_state = 1 AND storage_state != 'trash'
              ''');
            }

            if (names.contains('genre_state')) {
              await customStatement('''
                UPDATE bookmarks
                SET genre = genre_state
                WHERE genre_state IS NOT NULL AND genre_state != ''
              ''');
            }

            if (names.contains('deleted_at_state')) {
              final deletedRows = await customSelect('''
                SELECT id, deleted_at_state
                FROM bookmarks
                WHERE deleted_at_state IS NOT NULL
              ''').get();
              for (final row in deletedRows) {
                final raw = row.readNullable<String>('deleted_at_state');
                final parsed = raw == null ? null : DateTime.tryParse(raw);
                await (update(bookmarks)..where((b) => b.id.equals(row.read<int>('id')))).write(
                  BookmarksCompanion(
                    storageState: const Value('trash'),
                    deletedAt: Value(parsed),
                  ),
                );
              }
            }
          }
          if (from < 12) {
            final existing = await customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
            ).get();
            final tableNames = existing.map((row) => row.read<String>('name')).toSet();

            if (!tableNames.contains('workspaces')) {
              await m.createTable(workspaces);
            } else {
              final columns = await customSelect('PRAGMA table_info(workspaces)').get();
              final names = columns.map((row) => row.read<String>('name')).toSet();
              if (!names.contains('icon')) {
                await customStatement("ALTER TABLE workspaces ADD COLUMN icon TEXT NOT NULL DEFAULT '📁'");
              }
              if (!names.contains('color_value')) {
                await customStatement('ALTER TABLE workspaces ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4288585374');
              }
              if (!names.contains('sort_order')) {
                await customStatement('ALTER TABLE workspaces ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
              }
            }
            if (!tableNames.contains('bookmark_workspace')) {
              await m.createTable(bookmarkWorkspaces);
            }
            if (!tableNames.contains('saved_view_workspace')) {
              await m.createTable(savedViewWorkspaces);
            }
            if (!tableNames.contains('workspace_settings')) {
              await m.createTable(workspaceSettings);
            }
          }
          if (from < 13) {
            final existing = await customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
            ).get();
            final tableNames = existing.map((row) => row.read<String>('name')).toSet();

            if (!tableNames.contains('tag_groups')) {
              await m.createTable(tagGroups);
            }

            final tagColumns = await customSelect('PRAGMA table_info(tags)').get();
            final tagColumnNames = tagColumns.map((row) => row.read<String>('name')).toSet();
            if (!tagColumnNames.contains('group_id')) {
              await m.addColumn(tags, tags.groupId);
            }

            if (!tableNames.contains('bookmark_attachments')) {
              await m.createTable(bookmarkAttachments);
            }
            await customStatement(
              'CREATE INDEX IF NOT EXISTS bookmark_attachments_bookmark_id_idx '
              'ON bookmark_attachments(bookmark_id)',
            );

            if (!tableNames.contains('pdf_annotations')) {
              await m.createTable(pdfAnnotations);
            }
            await customStatement(
              'CREATE INDEX IF NOT EXISTS pdf_annotations_attachment_idx '
              'ON pdf_annotations(attachment_id, page_number)',
            );
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

  Future<List<PhotoRecord>> _photosForBookmark(int bookmarkId) {
    final query = select(photos).join([innerJoin(bookmarkPhotos, bookmarkPhotos.photoId.equalsExp(photos.id))])
      ..where(bookmarkPhotos.bookmarkId.equals(bookmarkId))
      ..orderBy([OrderingTerm.asc(photos.createdAt)]);
    return query.map((row) => _resolvedPhoto(row.readTable(photos))).get();
  }

  Future<List<CollectionRecord>> _collectionsForBookmark(int bookmarkId) {
    final query = select(collections).join([
      innerJoin(bookmarkCollections, bookmarkCollections.collectionId.equalsExp(collections.id)),
    ])
      ..where(bookmarkCollections.bookmarkId.equals(bookmarkId))
      ..orderBy([OrderingTerm.asc(collections.name)]);
    return query.map((row) => row.readTable(collections)).get();
  }

  Future<PhotoRecord?> _coverPhotoForBookmark(int bookmarkId) async {
    final query = select(photos).join([innerJoin(bookmarkPhotos, bookmarkPhotos.photoId.equalsExp(photos.id))])
      ..where(bookmarkPhotos.bookmarkId.equals(bookmarkId) & bookmarkPhotos.isCover.equals(true));
    final row = await query.getSingleOrNull();
    final photo = row?.readTable(photos);
    return photo == null ? null : _resolvedPhoto(photo);
  }

  Future<List<Tag>> _tagsForSavedView(int savedViewId) {
    final query = select(tags).join([innerJoin(savedViewTags, savedViewTags.tagId.equalsExp(tags.id))])
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
        status: bookmark.status,
        readingStatus: bookmark.readingStatus,
        storageState: bookmark.storageState,
        genre: bookmark.genre,
        deletedAt: bookmark.deletedAt,
        rating: bookmark.rating,
        lastOpenedAt: bookmark.lastOpenedAt,
        openCount: bookmark.openCount,
        tags: await _tagsForBookmark(bookmark.id),
        people: await _peopleForBookmark(bookmark.id),
        photos: await _photosForBookmark(bookmark.id),
        collections: await _collectionsForBookmark(bookmark.id),
        coverPhoto: await _coverPhotoForBookmark(bookmark.id),
      );

  Stream<List<BookmarkItem>> watchBookmarkItems() {
    final trigger = customSelect(
      'SELECT b.id FROM bookmarks b LEFT JOIN bookmark_tags bt ON bt.bookmark_id = b.id LEFT JOIN bookmark_people bp ON bp.bookmark_id = b.id LEFT JOIN bookmark_photos bph ON bph.bookmark_id = b.id LEFT JOIN bookmark_collections bc ON bc.bookmark_id = b.id GROUP BY b.id',
      readsFrom: {bookmarks, bookmarkTags, tags, bookmarkPeople, people, bookmarkPhotos, photos, bookmarkCollections, collections},
    ).watch();
    return trigger.asyncMap((_) async {
      final rows = await select(bookmarks).get();
      return Future.wait(rows.map(_toItem));
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
  }) => transaction(() async {
        await (update(savedViews)..where((v) => v.id.equals(id))).write(SavedViewsCompanion(
          name: Value(name), layoutType: Value(layoutType), searchQuery: Value(searchQuery),
          favoritesOnly: Value(favoritesOnly), tagMatchMode: Value(tagMatchMode),
          sortField: Value(sortField), sortDirection: Value(sortDirection), visibleProperties: Value(visibleProperties),
          statusFilter: Value(statusFilter), minRating: Value(minRating.clamp(0, 5)),
        ));
        await _setSavedViewTags(id, tagIds);
      });

  Future<int> deleteSavedView(int id) => (delete(savedViews)..where((v) => v.id.equals(id))).go();
}
), '');
    if (root == null || root.isEmpty) return path;
    return '$root/${path.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '')}';
  }

  String toStoredPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final root = profileDirectoryPath?.replaceAll('\\', '/').replaceAll(RegExp(r'/+

  @override
  int get schemaVersion => 13;

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
            final info = await customSelect('PRAGMA table_info(bookmarks)').get();
            final names = info.map((row) => row.read<String>('name')).toSet();

            if (!names.contains('reading_status')) {
              await m.addColumn(bookmarks, bookmarks.readingStatus);
            }
            if (!names.contains('storage_state')) {
              await m.addColumn(bookmarks, bookmarks.storageState);
            }
            if (!names.contains('genre')) {
              await m.addColumn(bookmarks, bookmarks.genre);
            }
            if (!names.contains('deleted_at')) {
              await m.addColumn(bookmarks, bookmarks.deletedAt);
            }

            await customStatement('''
              UPDATE bookmarks
              SET reading_status = CASE
                    WHEN status IN ('unread', 'later', 'in_progress', 'done') THEN status
                    ELSE 'unread'
                  END,
                  storage_state = CASE
                    WHEN status = 'archived' THEN 'archived'
                    ELSE storage_state
                  END
            ''');

            if (names.contains('inbox_state')) {
              await customStatement('''
                UPDATE bookmarks
                SET storage_state = 'inbox'
                WHERE inbox_state = 1 AND storage_state != 'trash'
              ''');
            }

            if (names.contains('genre_state')) {
              await customStatement('''
                UPDATE bookmarks
                SET genre = genre_state
                WHERE genre_state IS NOT NULL AND genre_state != ''
              ''');
            }

            if (names.contains('deleted_at_state')) {
              final deletedRows = await customSelect('''
                SELECT id, deleted_at_state
                FROM bookmarks
                WHERE deleted_at_state IS NOT NULL
              ''').get();
              for (final row in deletedRows) {
                final raw = row.readNullable<String>('deleted_at_state');
                final parsed = raw == null ? null : DateTime.tryParse(raw);
                await (update(bookmarks)..where((b) => b.id.equals(row.read<int>('id')))).write(
                  BookmarksCompanion(
                    storageState: const Value('trash'),
                    deletedAt: Value(parsed),
                  ),
                );
              }
            }
          }
          if (from < 12) {
            final existing = await customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
            ).get();
            final tableNames = existing.map((row) => row.read<String>('name')).toSet();

            if (!tableNames.contains('workspaces')) {
              await m.createTable(workspaces);
            } else {
              final columns = await customSelect('PRAGMA table_info(workspaces)').get();
              final names = columns.map((row) => row.read<String>('name')).toSet();
              if (!names.contains('icon')) {
                await customStatement("ALTER TABLE workspaces ADD COLUMN icon TEXT NOT NULL DEFAULT '📁'");
              }
              if (!names.contains('color_value')) {
                await customStatement('ALTER TABLE workspaces ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4288585374');
              }
              if (!names.contains('sort_order')) {
                await customStatement('ALTER TABLE workspaces ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
              }
            }
            if (!tableNames.contains('bookmark_workspace')) {
              await m.createTable(bookmarkWorkspaces);
            }
            if (!tableNames.contains('saved_view_workspace')) {
              await m.createTable(savedViewWorkspaces);
            }
            if (!tableNames.contains('workspace_settings')) {
              await m.createTable(workspaceSettings);
            }
          }
          if (from < 13) {
            final existing = await customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
            ).get();
            final tableNames = existing.map((row) => row.read<String>('name')).toSet();

            if (!tableNames.contains('tag_groups')) {
              await m.createTable(tagGroups);
            }

            final tagColumns = await customSelect('PRAGMA table_info(tags)').get();
            final tagColumnNames = tagColumns.map((row) => row.read<String>('name')).toSet();
            if (!tagColumnNames.contains('group_id')) {
              await m.addColumn(tags, tags.groupId);
            }

            if (!tableNames.contains('bookmark_attachments')) {
              await m.createTable(bookmarkAttachments);
            }
            await customStatement(
              'CREATE INDEX IF NOT EXISTS bookmark_attachments_bookmark_id_idx '
              'ON bookmark_attachments(bookmark_id)',
            );

            if (!tableNames.contains('pdf_annotations')) {
              await m.createTable(pdfAnnotations);
            }
            await customStatement(
              'CREATE INDEX IF NOT EXISTS pdf_annotations_attachment_idx '
              'ON pdf_annotations(attachment_id, page_number)',
            );
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

  Future<List<PhotoRecord>> _photosForBookmark(int bookmarkId) {
    final query = select(photos).join([innerJoin(bookmarkPhotos, bookmarkPhotos.photoId.equalsExp(photos.id))])
      ..where(bookmarkPhotos.bookmarkId.equals(bookmarkId))
      ..orderBy([OrderingTerm.asc(photos.createdAt)]);
    return query.map((row) => row.readTable(photos)).get();
  }

  Future<List<CollectionRecord>> _collectionsForBookmark(int bookmarkId) {
    final query = select(collections).join([
      innerJoin(bookmarkCollections, bookmarkCollections.collectionId.equalsExp(collections.id)),
    ])
      ..where(bookmarkCollections.bookmarkId.equals(bookmarkId))
      ..orderBy([OrderingTerm.asc(collections.name)]);
    return query.map((row) => row.readTable(collections)).get();
  }

  Future<PhotoRecord?> _coverPhotoForBookmark(int bookmarkId) async {
    final query = select(photos).join([innerJoin(bookmarkPhotos, bookmarkPhotos.photoId.equalsExp(photos.id))])
      ..where(bookmarkPhotos.bookmarkId.equals(bookmarkId) & bookmarkPhotos.isCover.equals(true));
    final row = await query.getSingleOrNull();
    return row?.readTable(photos);
  }

  Future<List<Tag>> _tagsForSavedView(int savedViewId) {
    final query = select(tags).join([innerJoin(savedViewTags, savedViewTags.tagId.equalsExp(tags.id))])
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
        status: bookmark.status,
        readingStatus: bookmark.readingStatus,
        storageState: bookmark.storageState,
        genre: bookmark.genre,
        deletedAt: bookmark.deletedAt,
        rating: bookmark.rating,
        lastOpenedAt: bookmark.lastOpenedAt,
        openCount: bookmark.openCount,
        tags: await _tagsForBookmark(bookmark.id),
        people: await _peopleForBookmark(bookmark.id),
        photos: await _photosForBookmark(bookmark.id),
        collections: await _collectionsForBookmark(bookmark.id),
        coverPhoto: await _coverPhotoForBookmark(bookmark.id),
      );

  Stream<List<BookmarkItem>> watchBookmarkItems() {
    final trigger = customSelect(
      'SELECT b.id FROM bookmarks b LEFT JOIN bookmark_tags bt ON bt.bookmark_id = b.id LEFT JOIN bookmark_people bp ON bp.bookmark_id = b.id LEFT JOIN bookmark_photos bph ON bph.bookmark_id = b.id LEFT JOIN bookmark_collections bc ON bc.bookmark_id = b.id GROUP BY b.id',
      readsFrom: {bookmarks, bookmarkTags, tags, bookmarkPeople, people, bookmarkPhotos, photos, bookmarkCollections, collections},
    ).watch();
    return trigger.asyncMap((_) async {
      final rows = await select(bookmarks).get();
      return Future.wait(rows.map(_toItem));
    });
  }

  Stream<List<Tag>> watchAllTags() => (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  Stream<List<Person>> watchAllPeople() => (select(people)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();
  Stream<List<PhotoRecord>> watchAllPhotos() => (select(photos)..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).watch();
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
      into(photos).insert(PhotosCompanion.insert(path: path, title: Value(title), note: Value(note), tags: Value(_normalizeNamesText(tagNames))));

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
  }) => transaction(() async {
        await (update(savedViews)..where((v) => v.id.equals(id))).write(SavedViewsCompanion(
          name: Value(name), layoutType: Value(layoutType), searchQuery: Value(searchQuery),
          favoritesOnly: Value(favoritesOnly), tagMatchMode: Value(tagMatchMode),
          sortField: Value(sortField), sortDirection: Value(sortDirection), visibleProperties: Value(visibleProperties),
          statusFilter: Value(statusFilter), minRating: Value(minRating.clamp(0, 5)),
        ));
        await _setSavedViewTags(id, tagIds);
      });

  Future<int> deleteSavedView(int id) => (delete(savedViews)..where((v) => v.id.equals(id))).go();
}
), '');
    if (root == null || root.isEmpty || !normalized.startsWith('$root/')) {
      return path;
    }
    return normalized.substring(root.length + 1);
  }

  PhotoRecord _resolvedPhoto(PhotoRecord photo) => PhotoRecord(
        id: photo.id,
        path: resolveStoredPath(photo.path),
        title: photo.title,
        note: photo.note,
        tags: photo.tags,
        createdAt: photo.createdAt,
      );

  @override
  int get schemaVersion => 13;

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
            final info = await customSelect('PRAGMA table_info(bookmarks)').get();
            final names = info.map((row) => row.read<String>('name')).toSet();

            if (!names.contains('reading_status')) {
              await m.addColumn(bookmarks, bookmarks.readingStatus);
            }
            if (!names.contains('storage_state')) {
              await m.addColumn(bookmarks, bookmarks.storageState);
            }
            if (!names.contains('genre')) {
              await m.addColumn(bookmarks, bookmarks.genre);
            }
            if (!names.contains('deleted_at')) {
              await m.addColumn(bookmarks, bookmarks.deletedAt);
            }

            await customStatement('''
              UPDATE bookmarks
              SET reading_status = CASE
                    WHEN status IN ('unread', 'later', 'in_progress', 'done') THEN status
                    ELSE 'unread'
                  END,
                  storage_state = CASE
                    WHEN status = 'archived' THEN 'archived'
                    ELSE storage_state
                  END
            ''');

            if (names.contains('inbox_state')) {
              await customStatement('''
                UPDATE bookmarks
                SET storage_state = 'inbox'
                WHERE inbox_state = 1 AND storage_state != 'trash'
              ''');
            }

            if (names.contains('genre_state')) {
              await customStatement('''
                UPDATE bookmarks
                SET genre = genre_state
                WHERE genre_state IS NOT NULL AND genre_state != ''
              ''');
            }

            if (names.contains('deleted_at_state')) {
              final deletedRows = await customSelect('''
                SELECT id, deleted_at_state
                FROM bookmarks
                WHERE deleted_at_state IS NOT NULL
              ''').get();
              for (final row in deletedRows) {
                final raw = row.readNullable<String>('deleted_at_state');
                final parsed = raw == null ? null : DateTime.tryParse(raw);
                await (update(bookmarks)..where((b) => b.id.equals(row.read<int>('id')))).write(
                  BookmarksCompanion(
                    storageState: const Value('trash'),
                    deletedAt: Value(parsed),
                  ),
                );
              }
            }
          }
          if (from < 12) {
            final existing = await customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
            ).get();
            final tableNames = existing.map((row) => row.read<String>('name')).toSet();

            if (!tableNames.contains('workspaces')) {
              await m.createTable(workspaces);
            } else {
              final columns = await customSelect('PRAGMA table_info(workspaces)').get();
              final names = columns.map((row) => row.read<String>('name')).toSet();
              if (!names.contains('icon')) {
                await customStatement("ALTER TABLE workspaces ADD COLUMN icon TEXT NOT NULL DEFAULT '📁'");
              }
              if (!names.contains('color_value')) {
                await customStatement('ALTER TABLE workspaces ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4288585374');
              }
              if (!names.contains('sort_order')) {
                await customStatement('ALTER TABLE workspaces ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
              }
            }
            if (!tableNames.contains('bookmark_workspace')) {
              await m.createTable(bookmarkWorkspaces);
            }
            if (!tableNames.contains('saved_view_workspace')) {
              await m.createTable(savedViewWorkspaces);
            }
            if (!tableNames.contains('workspace_settings')) {
              await m.createTable(workspaceSettings);
            }
          }
          if (from < 13) {
            final existing = await customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
            ).get();
            final tableNames = existing.map((row) => row.read<String>('name')).toSet();

            if (!tableNames.contains('tag_groups')) {
              await m.createTable(tagGroups);
            }

            final tagColumns = await customSelect('PRAGMA table_info(tags)').get();
            final tagColumnNames = tagColumns.map((row) => row.read<String>('name')).toSet();
            if (!tagColumnNames.contains('group_id')) {
              await m.addColumn(tags, tags.groupId);
            }

            if (!tableNames.contains('bookmark_attachments')) {
              await m.createTable(bookmarkAttachments);
            }
            await customStatement(
              'CREATE INDEX IF NOT EXISTS bookmark_attachments_bookmark_id_idx '
              'ON bookmark_attachments(bookmark_id)',
            );

            if (!tableNames.contains('pdf_annotations')) {
              await m.createTable(pdfAnnotations);
            }
            await customStatement(
              'CREATE INDEX IF NOT EXISTS pdf_annotations_attachment_idx '
              'ON pdf_annotations(attachment_id, page_number)',
            );
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

  Future<List<PhotoRecord>> _photosForBookmark(int bookmarkId) {
    final query = select(photos).join([innerJoin(bookmarkPhotos, bookmarkPhotos.photoId.equalsExp(photos.id))])
      ..where(bookmarkPhotos.bookmarkId.equals(bookmarkId))
      ..orderBy([OrderingTerm.asc(photos.createdAt)]);
    return query.map((row) => row.readTable(photos)).get();
  }

  Future<List<CollectionRecord>> _collectionsForBookmark(int bookmarkId) {
    final query = select(collections).join([
      innerJoin(bookmarkCollections, bookmarkCollections.collectionId.equalsExp(collections.id)),
    ])
      ..where(bookmarkCollections.bookmarkId.equals(bookmarkId))
      ..orderBy([OrderingTerm.asc(collections.name)]);
    return query.map((row) => row.readTable(collections)).get();
  }

  Future<PhotoRecord?> _coverPhotoForBookmark(int bookmarkId) async {
    final query = select(photos).join([innerJoin(bookmarkPhotos, bookmarkPhotos.photoId.equalsExp(photos.id))])
      ..where(bookmarkPhotos.bookmarkId.equals(bookmarkId) & bookmarkPhotos.isCover.equals(true));
    final row = await query.getSingleOrNull();
    return row?.readTable(photos);
  }

  Future<List<Tag>> _tagsForSavedView(int savedViewId) {
    final query = select(tags).join([innerJoin(savedViewTags, savedViewTags.tagId.equalsExp(tags.id))])
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
        status: bookmark.status,
        readingStatus: bookmark.readingStatus,
        storageState: bookmark.storageState,
        genre: bookmark.genre,
        deletedAt: bookmark.deletedAt,
        rating: bookmark.rating,
        lastOpenedAt: bookmark.lastOpenedAt,
        openCount: bookmark.openCount,
        tags: await _tagsForBookmark(bookmark.id),
        people: await _peopleForBookmark(bookmark.id),
        photos: await _photosForBookmark(bookmark.id),
        collections: await _collectionsForBookmark(bookmark.id),
        coverPhoto: await _coverPhotoForBookmark(bookmark.id),
      );

  Stream<List<BookmarkItem>> watchBookmarkItems() {
    final trigger = customSelect(
      'SELECT b.id FROM bookmarks b LEFT JOIN bookmark_tags bt ON bt.bookmark_id = b.id LEFT JOIN bookmark_people bp ON bp.bookmark_id = b.id LEFT JOIN bookmark_photos bph ON bph.bookmark_id = b.id LEFT JOIN bookmark_collections bc ON bc.bookmark_id = b.id GROUP BY b.id',
      readsFrom: {bookmarks, bookmarkTags, tags, bookmarkPeople, people, bookmarkPhotos, photos, bookmarkCollections, collections},
    ).watch();
    return trigger.asyncMap((_) async {
      final rows = await select(bookmarks).get();
      return Future.wait(rows.map(_toItem));
    });
  }

  Stream<List<Tag>> watchAllTags() => (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  Stream<List<Person>> watchAllPeople() => (select(people)..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();
  Stream<List<PhotoRecord>> watchAllPhotos() => (select(photos)..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).watch();
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
      into(photos).insert(PhotosCompanion.insert(path: path, title: Value(title), note: Value(note), tags: Value(_normalizeNamesText(tagNames))));

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
  }) => transaction(() async {
        await (update(savedViews)..where((v) => v.id.equals(id))).write(SavedViewsCompanion(
          name: Value(name), layoutType: Value(layoutType), searchQuery: Value(searchQuery),
          favoritesOnly: Value(favoritesOnly), tagMatchMode: Value(tagMatchMode),
          sortField: Value(sortField), sortDirection: Value(sortDirection), visibleProperties: Value(visibleProperties),
          statusFilter: Value(statusFilter), minRating: Value(minRating.clamp(0, 5)),
        ));
        await _setSavedViewTags(id, tagIds);
      });

  Future<int> deleteSavedView(int id) => (delete(savedViews)..where((v) => v.id.equals(id))).go();
}
