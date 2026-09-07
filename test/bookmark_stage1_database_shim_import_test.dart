import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark Stage1 imports Database presentation widgets canonically', () {
    final source = File('lib/views/bookmark_unified_stage1_page.dart')
        .readAsStringSync();

    expect(
      source,
      contains(
        "import '../features/database/presentation/widgets/database_create_tiles.dart';",
      ),
    );
    expect(
      source,
      contains(
        "import '../features/database/presentation/widgets/database_view_tabs.dart';",
      ),
    );
    expect(
      source,
      isNot(contains("import '../widgets/database_create_tiles.dart';")),
    );
    expect(
      source,
      isNot(contains("import '../widgets/database_view_tabs.dart';")),
    );
  });
}
