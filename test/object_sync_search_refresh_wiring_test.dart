import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production Object sync wires preview impact to focused Search refresh', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains(
        'onPreviewImageIngested: search.refreshObjectLabelDependents',
      ),
      reason:
          'background preview ingestion must notify the canonical focused Search refresh boundary',
    );
    expect(
      RegExp(r'_objectSyncService\(database\)\.syncWorkspace').allMatches(source),
      hasLength(2),
      reason:
          'both initial/profile bootstrap and workspace switching must use the same Search-aware Object sync composition',
    );
    expect(
      source,
      isNot(contains(
        'ObjectSyncService(\n      database,\n      enableRemotePreviewImages: true,\n    ).syncWorkspace',
      )),
      reason:
          'production preview sync must not bypass the focused completion callback',
    );
  });
}
