import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attachment failures keep stable privacy-safe boundaries', () {
    final source =
        File('lib/widgets/bookmark_attachment_section.dart').readAsStringSync();

    expect(
      source,
      contains('ファイルを添付できませんでした。もう一度お試しください。'),
    );
    expect(
      source,
      isNot(contains('ファイルを添付できませんでした: \$error')),
    );
    expect(
      source,
      contains("_debugFailure('attachment import', stackTrace);"),
    );
    expect(
      source,
      contains(
        "_debugFailure('best-effort PDF author creation', stackTrace);",
      ),
    );
    expect(source, isNot(contains('catch (_) {}')));

    final metadataUpdate = source.indexOf('await widget.repository.update(');
    final authorCreation =
        source.indexOf('for (final author in metadata.authors)');
    expect(metadataUpdate, greaterThanOrEqualTo(0));
    expect(authorCreation, greaterThan(metadataUpdate));
  });
}
