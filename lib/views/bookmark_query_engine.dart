import '../data/app_database.dart';

enum BookmarkStage1ViewType { gallery, list, table }

enum BookmarkStage1SortField { createdAt, title, url }

enum BookmarkStage1Property {
  image,
  url,
  tags,
  people,
  description,
  createdAt,
  favorite,
  status,
  rating,
  history,
}

const bookmarkStatusLabels = <String, String>{
  'unread': '未読',
  'later': '後で見る',
  'in_progress': '閲覧中 / 視聴中',
  'done': '完了 / 視聴済み',
  'archived': 'アーカイブ',
};

class BookmarkQuery {
  const BookmarkQuery({
    this.query = '',
    this.favoritesOnly = false,
    this.statusFilter = '',
    this.minRating = 0,
    this.personFilterId,
    this.photoFilterId,
    this.selectedTagIds = const {},
    this.includeDescendants = true,
    this.tagMatchMode = 'or',
    this.sortField = BookmarkStage1SortField.createdAt,
    this.sortAscending = false,
  });

  final String query;
  final bool favoritesOnly;
  final String statusFilter;
  final int minRating;
  final int? personFilterId;
  final int? photoFilterId;
  final Set<int> selectedTagIds;
  final bool includeDescendants;
  final String tagMatchMode;
  final BookmarkStage1SortField sortField;
  final bool sortAscending;

  Set<int> _descendantIds(int tagId, List<Tag> tags) {
    final result = <int>{};
    void visit(int parentId) {
      for (final child in tags.where((tag) => tag.parentTagId == parentId)) {
        if (result.add(child.id)) visit(child.id);
      }
    }

    visit(tagId);
    return result;
  }

  List<BookmarkItem> apply(
    Iterable<BookmarkItem> source,
    List<Tag> allTags,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    final result = source.where((bookmark) {
      if (favoritesOnly && !bookmark.favorite) return false;
      if (statusFilter.isNotEmpty && bookmark.status != statusFilter) {
        return false;
      }
      if (bookmark.rating < minRating) return false;
      if (personFilterId != null &&
          !bookmark.people.any((person) => person.id == personFilterId)) {
        return false;
      }
      if (photoFilterId != null &&
          !bookmark.photos.any((photo) => photo.id == photoFilterId)) {
        return false;
      }
      if (normalizedQuery.isNotEmpty) {
        final searchable = [
          bookmark.title,
          bookmark.url,
          bookmark.description ?? '',
          bookmarkStatusLabels[bookmark.status] ?? bookmark.status,
          ...bookmark.tags.map((tag) => tag.name),
          ...bookmark.people.map((person) => person.name),
        ].join(' ').toLowerCase();
        if (!searchable.contains(normalizedQuery)) return false;
      }
      if (selectedTagIds.isNotEmpty) {
        final bookmarkTagIds = bookmark.tags.map((tag) => tag.id).toSet();
        final selectedMatches = selectedTagIds.map((id) {
          final allowed = <int>{id};
          if (includeDescendants) {
            allowed.addAll(_descendantIds(id, allTags));
          }
          return allowed.any(bookmarkTagIds.contains);
        });
        final matches = tagMatchMode == 'and'
            ? selectedMatches.every((value) => value)
            : selectedMatches.any((value) => value);
        if (!matches) return false;
      }
      return true;
    }).toList();

    int compare(BookmarkItem a, BookmarkItem b) {
      final value = switch (sortField) {
        BookmarkStage1SortField.createdAt =>
          a.createdAt.compareTo(b.createdAt),
        BookmarkStage1SortField.title =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        BookmarkStage1SortField.url =>
          a.url.toLowerCase().compareTo(b.url.toLowerCase()),
      };
      return sortAscending ? value : -value;
    }

    result.sort(compare);
    return result;
  }
}
