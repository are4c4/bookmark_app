part of 'app_database.dart';

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

@DataClassName('PersonGroupRecord')
class PersonGroups extends Table {
  @override
  String get tableName => 'person_groups';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PersonGroupMembers extends Table {
  @override
  String get tableName => 'person_group_members';

  IntColumn get groupId => integer().references(PersonGroups, #id, onDelete: KeyAction.cascade)();
  IntColumn get personId => integer().references(People, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {groupId, personId};
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
  BoolColumn get includeDescendants =>
      boolean().withDefault(const Constant(true))();
  IntColumn get personFilterId =>
      integer().nullable().references(People, #id, onDelete: KeyAction.setNull)();
  IntColumn get photoFilterId =>
      integer().nullable().references(Photos, #id, onDelete: KeyAction.setNull)();
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

@DataClassName('DatabaseViewRecord')
class DatabaseViews extends Table {
  @override
  String get tableName => 'database_views';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId => integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get databaseKey => text()();
  TextColumn get name => text()();
  TextColumn get layoutType => text().withDefault(const Constant('gallery'))();
  TextColumn get filtersJson => text().withDefault(const Constant('{}'))();
  TextColumn get sortsJson => text().withDefault(const Constant('[]'))();
  TextColumn get visibleProperties => text().withDefault(const Constant(''))();
  TextColumn get propertyOrder => text().withDefault(const Constant(''))();
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('GenericDatabaseRow')
class GenericDatabases extends Table {
  @override
  String get tableName => 'generic_databases';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId => integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('🗃️'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('GenericPropertyRow')
class GenericProperties extends Table {
  @override
  String get tableName => 'generic_properties';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get databaseId => integer().references(GenericDatabases, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get configJson => text().withDefault(const Constant('{}'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('GenericRecordRow')
class GenericRecords extends Table {
  @override
  String get tableName => 'generic_records';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get databaseId => integer().references(GenericDatabases, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class GenericValues extends Table {
  @override
  String get tableName => 'generic_values';

  IntColumn get recordId => integer().references(GenericRecords, #id, onDelete: KeyAction.cascade)();
  IntColumn get propertyId => integer().references(GenericProperties, #id, onDelete: KeyAction.cascade)();
  TextColumn get valueJson => text().withDefault(const Constant('null'))();

  @override
  Set<Column<Object>> get primaryKey => {recordId, propertyId};
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
