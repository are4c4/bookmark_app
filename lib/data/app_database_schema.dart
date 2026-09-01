part of 'app_database.dart';

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
