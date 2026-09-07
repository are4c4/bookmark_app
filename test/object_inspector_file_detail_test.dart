import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Object inspector composes the canonical File detail host', () {
    final source = File('lib/views/object_inspector_page.dart').readAsStringSync();

    expect(
      source,
      contains(
        "import '../features/object/presentation/widgets/object_file_detail_panel_host.dart';",
      ),
    );
    expect(
      source,
      contains(
        "import '../services/canonical_file_detail_capabilities.dart';",
      ),
    );
    expect(source, contains('ObjectFileDetailPanelHost('));
    expect(source, contains('CanonicalFileDetailCapabilities.fromDatabase('));
    expect(source, contains('fileObjectTypeId: type.id'));
    expect(source, contains('fileObjectId: object.id'));
  });
}
