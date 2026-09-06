import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reorderable Bookmark roles use the shared anchored Property popover',
      () async {
    final source = await File(
      'lib/widgets/bookmark_reorderable_properties.dart',
    ).readAsString();

    expect(
      source,
      contains(
        "../features/database/presentation/widgets/property_add_popover.dart",
      ),
    );
    expect(source, contains('PropertyAddPopover('));
    expect(
      source,
      contains(
        "buttonKey: const ValueKey('bookmark-reorderable-person-role-add')",
      ),
    );
    expect(source, contains('normalizePersonRole(role)'));
    expect(source, contains('onPropertyOrderChanged([...propertyOrder, token]);'));
    expect(
      source,
      isNot(contains("title: const Text('人物プロパティを追加')")),
    );
    expect(source, isNot(contains('Future<void> _addRole(')));
  });
}
