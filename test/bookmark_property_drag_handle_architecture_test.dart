import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark Property rows reuse the shared deterministic drag handle', () {
    final source = File(
      'lib/widgets/bookmark_reorderable_properties.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("features/object/presentation/widgets/property_drag_handle.dart"),
    );
    expect(source, contains('const PropertyDragHandle()'));
    expect(source, contains('dragHandle: dragHandle'));
    expect(source, contains('ReorderableDragStartListener('));
    expect(source, isNot(contains('Icons.drag_indicator')));
    expect(source, isNot(contains('crossAxisAlignment: CrossAxisAlignment.start,\n                    children: [\n                      _dragHandle(context)')));
  });
}
