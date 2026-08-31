enum BookmarkReadingStatus {
  unread('unread', '未読'),
  later('later', '後で見る'),
  inProgress('in_progress', '閲覧中 / 視聴中'),
  done('done', '完了 / 視聴済み');

  const BookmarkReadingStatus(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static BookmarkReadingStatus fromStorage(String value) => switch (value) {
        'later' => later,
        'in_progress' => inProgress,
        'done' => done,
        _ => unread,
      };
}

enum BookmarkStorageState {
  inbox('inbox', '未整理'),
  active('active', '通常'),
  archived('archived', 'アーカイブ'),
  trashed('trashed', 'ゴミ箱');

  const BookmarkStorageState(this.storageValue, this.label);
  final String storageValue;
  final String label;

  static BookmarkStorageState fromStorage(String value) => switch (value) {
        'inbox' => inbox,
        'archived' => archived,
        'trashed' => trashed,
        _ => active,
      };
}

/// Compatibility mapping for the pre-migration schema where `archived` lived
/// in Bookmarks.status instead of the lifecycle/storage state.
BookmarkReadingStatus legacyReadingStatus(String value) =>
    value == 'archived' ? BookmarkReadingStatus.unread : BookmarkReadingStatus.fromStorage(value);

BookmarkStorageState legacyStorageState({
  required String bookmarkStatus,
  required bool inbox,
  required bool deleted,
}) {
  if (deleted) return BookmarkStorageState.trashed;
  if (bookmarkStatus == 'archived') return BookmarkStorageState.archived;
  if (inbox) return BookmarkStorageState.inbox;
  return BookmarkStorageState.active;
}
