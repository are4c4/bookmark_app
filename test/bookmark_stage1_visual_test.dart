import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _between(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'missing start marker: $start');
  expect(endIndex, greaterThan(startIndex), reason: 'missing end marker: $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  test('Stage1 list and table keep canonical bookmark visual routing', () {
    final source = File('lib/views/bookmark_unified_stage1_page.dart')
        .readAsStringSync();

    final imageHelper = _between(
      source,
      '  Widget _image(',
      '\n  Widget _list(',
    );
    expect(imageHelper, contains('BookmarkVisualImage('));
    expect(imageHelper, isNot(contains('Image.file(')));
    expect(imageHelper, isNot(contains('Image.network(')));
    expect(imageHelper, contains('double width = 60'));
    expect(imageHelper, contains('double height = 44'));

    final list = _between(
      source,
      '  Widget _list(',
      '\n  Widget _roleCell(',
    );
    expect(list, contains('width: 60'));
    expect(list, contains('height: 44'));
    expect(list, contains('child: _image(bookmark)'));

    final table = _between(
      source,
      '  Widget _table(',
      '\n  String _formatDate(',
    );
    expect(table, contains('width: 58'));
    expect(table, contains('height: 38'));
    expect(table, contains('child: _image(bookmark, width: 58, height: 38)'));
  });

  test('Stage1 bookmark opening delegates to shared View opening contract', () {
    final source = File('lib/views/bookmark_unified_stage1_page.dart')
        .readAsStringSync();

    final selectBookmark = _between(
      source,
      '  void _selectBookmark(',
      '\n  Future<void> _presentBookmark(',
    );
    expect(selectBookmark, contains('unawaited(_presentBookmark(bookmark))'));
    expect(selectBookmark, isNot(contains('_selectedBookmarkId = bookmark.id')));

    final presentBookmark = _between(
      source,
      '  Future<void> _presentBookmark(',
      '\n  Future<BookmarkPresentationUrlSource?> _resolveBookmarkUrl(',
    );
    expect(
      presentBookmark,
      contains('_databaseViewOpenModeService.resolve(view: activeView)'),
    );
    expect(presentBookmark, contains('_openPresentationHost.open('));
    expect(presentBookmark, contains('onSidePeek: ()'));
    expect(presentBookmark, contains('detailBuilder: (presentationContext)'));
    expect(presentBookmark, contains('BookmarkDetailPanel('));

    final menu = _between(
      source,
      '  Widget _bookmarkMenu(',
      '\n  Map<String, List<Person>> _roleGroups(',
    );
    expect(menu, contains("if (value == 'detail') {\n            _selectBookmark(bookmark);"));
  });
}
