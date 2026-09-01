import '../data/person_roles.dart';
import 'bookmark_query_engine.dart';

String bookmarkPropertyKey(BookmarkStage1Property property) => switch (property) {
      BookmarkStage1Property.image => 'image',
      BookmarkStage1Property.url => 'url',
      BookmarkStage1Property.tags => 'tags',
      BookmarkStage1Property.people => 'people',
      BookmarkStage1Property.description => 'description',
      BookmarkStage1Property.createdAt => 'createdAt',
      BookmarkStage1Property.favorite => 'favorite',
      BookmarkStage1Property.status => 'status',
      BookmarkStage1Property.rating => 'rating',
      BookmarkStage1Property.history => 'history',
    };

BookmarkStage1Property? bookmarkPropertyFromKey(String key) {
  for (final property in BookmarkStage1Property.values) {
    if (bookmarkPropertyKey(property) == key) return property;
  }
  return null;
}

String bookmarkPropertyLabel(BookmarkStage1Property property) => switch (property) {
      BookmarkStage1Property.image => '画像',
      BookmarkStage1Property.url => 'URL',
      BookmarkStage1Property.tags => 'タグ',
      BookmarkStage1Property.people => '人物（すべて）',
      BookmarkStage1Property.description => '説明',
      BookmarkStage1Property.createdAt => '登録日時',
      BookmarkStage1Property.favorite => 'お気に入り',
      BookmarkStage1Property.status => 'ステータス',
      BookmarkStage1Property.rating => '評価',
      BookmarkStage1Property.history => '履歴',
    };

List<String> defaultBookmarkPropertyOrder() => [
      ...BookmarkStage1Property.values.map(bookmarkPropertyKey),
      ...defaultPersonRoles.map((role) => 'role:$role'),
    ];

List<String> normalizeBookmarkPropertyOrder(Iterable<String> preferred) {
  final result = <String>[];
  final seen = <String>{};
  for (final key in preferred.map((value) => value.trim())) {
    if (key.isEmpty || !seen.add(key)) continue;
    if (key.startsWith('role:') || bookmarkPropertyFromKey(key) != null) {
      result.add(key);
    }
  }
  for (final key in defaultBookmarkPropertyOrder()) {
    if (seen.add(key)) result.add(key);
  }
  return result;
}

List<BookmarkStage1Property> orderedVisibleBookmarkProperties(
  Iterable<String> order,
  Set<BookmarkStage1Property> visible,
) {
  final result = <BookmarkStage1Property>[];
  for (final key in normalizeBookmarkPropertyOrder(order)) {
    final property = bookmarkPropertyFromKey(key);
    if (property != null && visible.contains(property)) result.add(property);
  }
  return result;
}

List<String> orderedVisiblePersonRoles(
  Iterable<String> order,
  Set<String> visibleRoles,
) {
  final result = <String>[];
  for (final key in normalizeBookmarkPropertyOrder(order)) {
    if (!key.startsWith('role:')) continue;
    final role = key.substring(5);
    if (visibleRoles.contains(role)) result.add(role);
  }
  return result;
}

List<String> visibleBookmarkPropertyTokens(
  Iterable<String> order,
  Set<BookmarkStage1Property> visible,
  Set<String> visibleRoles,
) {
  final result = <String>[];
  for (final key in normalizeBookmarkPropertyOrder(order)) {
    if (key.startsWith('role:')) {
      if (visibleRoles.contains(key.substring(5))) result.add(key);
      continue;
    }
    final property = bookmarkPropertyFromKey(key);
    if (property != null && visible.contains(property)) result.add(key);
  }
  return result;
}
