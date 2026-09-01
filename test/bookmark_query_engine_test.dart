import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/views/bookmark_query_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026);
  late Tag parent;
  late Tag child;
  late Tag other;
  late List<Tag> tags;

  setUp(() {
    parent = Tag(
      id: 1,
      name: '開発',
      parentTagId: null,
      groupId: null,
      createdAt: createdAt,
    );
    child = Tag(
      id: 2,
      name: 'Flutter',
      parentTagId: 1,
      groupId: null,
      createdAt: createdAt,
    );
    other = Tag(
      id: 3,
      name: '資料',
      parentTagId: null,
      groupId: null,
      createdAt: createdAt,
    );
    tags = [parent, child, other];
  });

  BookmarkItem item({
    required int id,
    required String title,
    List<Tag> itemTags = const [],
    bool favorite = false,
    int rating = 0,
  }) =>
      BookmarkItem(
        id: id,
        url: 'https://example.com/$id',
        title: title,
        createdAt: createdAt.add(Duration(days: id)),
        favorite: favorite,
        status: 'unread',
        rating: rating,
        openCount: 0,
        tags: itemTags,
        people: const [],
        photos: const [],
        collections: const [],
      );

  test('parent tag filter includes descendants', () {
    final result = BookmarkQuery(
      selectedTagIds: {parent.id},
      includeDescendants: true,
    ).apply(
      [
        item(id: 1, title: 'Flutter', itemTags: [child]),
        item(id: 2, title: 'Other', itemTags: [other]),
      ],
      tags,
    );

    expect(result.map((bookmark) => bookmark.id), [1]);
  });

  test('and mode requires every selected tag', () {
    final result = BookmarkQuery(
      selectedTagIds: {parent.id, other.id},
      tagMatchMode: 'and',
    ).apply(
      [
        item(id: 1, title: 'Both', itemTags: [parent, other]),
        item(id: 2, title: 'One', itemTags: [parent]),
      ],
      tags,
    );

    expect(result.map((bookmark) => bookmark.id), [1]);
  });

  test('search, rating and sort remain deterministic', () {
    final result = BookmarkQuery(
      query: 'flutter',
      minRating: 3,
      sortField: BookmarkStage1SortField.title,
      sortAscending: true,
    ).apply(
      [
        item(id: 1, title: 'Flutter Zebra', rating: 4),
        item(id: 2, title: 'Flutter Alpha', rating: 5),
        item(id: 3, title: 'Flutter Low', rating: 1),
      ],
      tags,
    );

    expect(
      result.map((bookmark) => bookmark.title),
      ['Flutter Alpha', 'Flutter Zebra'],
    );
  });
}
