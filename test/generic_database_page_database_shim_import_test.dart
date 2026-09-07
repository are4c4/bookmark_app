import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generic Database uses canonical Database presentation imports', () {
    final source =
        File('lib/views/generic_database_page.dart').readAsStringSync();

    const canonicalImports = <String>[
      "import '../features/database/presentation/widgets/database_create_tiles.dart';",
      "import '../features/database/presentation/widgets/database_view_tabs.dart';",
      "import '../features/database/presentation/widgets/resizable_detail_pane.dart';",
    ];
    const legacyImports = <String>[
      "import '../widgets/database_create_tiles.dart';",
      "import '../widgets/database_view_tabs.dart';",
      "import '../widgets/resizable_detail_pane.dart';",
    ];

    for (final import in canonicalImports) {
      expect(source, contains(import), reason: 'missing canonical import: $import');
    }
    for (final import in legacyImports) {
      expect(source, isNot(contains(import)), reason: 'legacy shim import returned: $import');
    }
  });
}
