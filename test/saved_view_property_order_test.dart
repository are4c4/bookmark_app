import 'package:bookmark_app/views/bookmark_property_order.dart';
import 'package:bookmark_app/views/bookmark_query_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('property order keeps custom order and role positions', () {
    final order = normalizeBookmarkPropertyOrder([
      'status',
      'role:著者',
      'tags',
      'url',
    ]);
    final visibleProperties = <BookmarkStage1Property>{
      BookmarkStage1Property.status,
      BookmarkStage1Property.tags,
      BookmarkStage1Property.url,
    };
    final visibleRoles = <String>{'著者'};

    expect(
      visibleBookmarkPropertyTokens(order, visibleProperties, visibleRoles),
      ['status', 'role:著者', 'tags', 'url'],
    );
    expect(
      orderedVisibleBookmarkProperties(order, visibleProperties),
      [
        BookmarkStage1Property.status,
        BookmarkStage1Property.tags,
        BookmarkStage1Property.url,
      ],
    );
    expect(orderedVisiblePersonRoles(order, visibleRoles), ['著者']);
  });
}
