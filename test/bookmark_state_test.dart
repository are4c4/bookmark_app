import 'package:bookmark_app/domain/bookmark_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('legacy bookmark state mapping', () {
    test('archived status becomes archived storage state', () {
      expect(
        legacyStorageState(
          bookmarkStatus: 'archived',
          inbox: false,
          deleted: false,
        ),
        BookmarkStorageState.archived,
      );
      expect(
        legacyReadingStatus('archived'),
        BookmarkReadingStatus.unread,
      );
    });

    test('trash wins over archived and inbox', () {
      expect(
        legacyStorageState(
          bookmarkStatus: 'archived',
          inbox: true,
          deleted: true,
        ),
        BookmarkStorageState.trashed,
      );
    });

    test('inbox maps to inbox when otherwise active', () {
      expect(
        legacyStorageState(
          bookmarkStatus: 'unread',
          inbox: true,
          deleted: false,
        ),
        BookmarkStorageState.inbox,
      );
    });

    test('database trash value maps to trashed domain state', () {
      expect(
        BookmarkStorageState.fromStorage('trash'),
        BookmarkStorageState.trashed,
      );
      expect(BookmarkStorageState.trashed.storageValue, 'trash');
    });

    test('old trashed spelling remains readable for compatibility', () {
      expect(
        BookmarkStorageState.fromStorage('trashed'),
        BookmarkStorageState.trashed,
      );
    });

    test('reading status migration preserves normal progress states', () {
      expect(legacyReadingStatus('later'), BookmarkReadingStatus.later);
      expect(legacyReadingStatus('in_progress'), BookmarkReadingStatus.inProgress);
      expect(legacyReadingStatus('done'), BookmarkReadingStatus.done);
    });
  });
}
