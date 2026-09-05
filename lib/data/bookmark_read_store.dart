import 'package:drift/drift.dart';

import 'app_database.dart';

class BookmarkReadStore {
  BookmarkReadStore(this.database);

  final AppDatabase database;

  Stream<List<BookmarkItem>> watchItems() {
    final trigger = database.customSelect(
      'SELECT b.id FROM bookmarks b '
      'LEFT JOIN bookmark_tags bt ON bt.bookmark_id = b.id '
      'LEFT JOIN bookmark_people bp ON bp.bookmark_id = b.id '
      'LEFT JOIN bookmark_photos bph ON bph.bookmark_id = b.id '
      'LEFT JOIN bookmark_collections bc ON bc.bookmark_id = b.id '
      'GROUP BY b.id',
      readsFrom: {
        database.bookmarks,
        database.bookmarkTags,
        database.tags,
        database.bookmarkPeople,
        database.people,
        database.bookmarkPhotos,
        database.photos,
        database.bookmarkCollections,
        database.collections,
      },
    ).watch();

    return trigger.asyncMap((_) async {
      final bookmarkRows = await database.select(database.bookmarks).get();
      final tagsByBookmark = <int, List<Tag>>{};
      final peopleByBookmark = <int, Map<int, Person>>{};
      final photosByBookmark = <int, List<PhotoRecord>>{};
      final coverByBookmark = <int, PhotoRecord>{};
      final collectionsByBookmark = <int, List<CollectionRecord>>{};

      final tagRows = await database.select(database.bookmarkTags).join([
        innerJoin(
          database.tags,
          database.tags.id.equalsExp(database.bookmarkTags.tagId),
        ),
      ]).get();
      for (final row in tagRows) {
        final relation = row.readTable(database.bookmarkTags);
        tagsByBookmark
            .putIfAbsent(relation.bookmarkId, () => <Tag>[])
            .add(row.readTable(database.tags));
      }

      final peopleRows = await database.select(database.bookmarkPeople).join([
        innerJoin(
          database.people,
          database.people.id.equalsExp(database.bookmarkPeople.personId),
        ),
      ]).get();
      for (final row in peopleRows) {
        final relation = row.readTable(database.bookmarkPeople);
        final person = row.readTable(database.people);
        peopleByBookmark
            .putIfAbsent(relation.bookmarkId, () => <int, Person>{})[person.id] =
            person;
      }

      final photoRows = await database.select(database.bookmarkPhotos).join([
        innerJoin(
          database.photos,
          database.photos.id.equalsExp(database.bookmarkPhotos.photoId),
        ),
      ]).get();
      for (final row in photoRows) {
        final relation = row.readTable(database.bookmarkPhotos);
        final photo = _resolvedPhoto(row.readTable(database.photos));
        photosByBookmark
            .putIfAbsent(relation.bookmarkId, () => <PhotoRecord>[])
            .add(photo);
        if (relation.isCover) coverByBookmark[relation.bookmarkId] = photo;
      }

      final collectionRows =
          await database.select(database.bookmarkCollections).join([
        innerJoin(
          database.collections,
          database.collections.id.equalsExp(database.bookmarkCollections.collectionId),
        ),
      ]).get();
      for (final row in collectionRows) {
        final relation = row.readTable(database.bookmarkCollections);
        collectionsByBookmark
            .putIfAbsent(relation.bookmarkId, () => <CollectionRecord>[])
            .add(row.readTable(database.collections));
      }

      for (final values in tagsByBookmark.values) {
        values.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      }
      for (final values in photosByBookmark.values) {
        values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
      for (final values in collectionsByBookmark.values) {
        values.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
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
              people:
                  (peopleByBookmark[bookmark.id]?.values.toList() ?? <Person>[])
                    ..sort(
                      (a, b) => a.name
                          .toLowerCase()
                          .compareTo(b.name.toLowerCase()),
                    ),
              photos: photosByBookmark[bookmark.id] ?? const [],
              collections: collectionsByBookmark[bookmark.id] ?? const [],
              coverPhoto: coverByBookmark[bookmark.id],
            ),
          )
          .toList();
    });
  }

  PhotoRecord _resolvedPhoto(PhotoRecord photo) => PhotoRecord(
        id: photo.id,
        path: database.pathResolver.resolveStoredPath(photo.path),
        title: photo.title,
        note: photo.note,
        tags: photo.tags,
        createdAt: photo.createdAt,
      );
}
