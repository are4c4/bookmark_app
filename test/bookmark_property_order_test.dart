import 'package:bookmark_app/views/bookmark_property_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detail-only property keys survive normalization', () {
    final order = normalizeBookmarkPropertyOrder([
      'rating',
      'genre',
      'role:監督',
      'collections',
      'status',
    ]);

    expect(order.take(5), [
      'rating',
      'genre',
      'role:監督',
      'collections',
      'status',
    ]);
    expect(order, contains('tags'));
    expect(order, contains('role:出演者'));
  });
}
