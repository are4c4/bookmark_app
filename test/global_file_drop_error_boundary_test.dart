import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global file drop failure boundary is stable and privacy-safe', () {
    final source = File('lib/widgets/global_file_drop_layer.dart')
        .readAsStringSync();

    expect(
      source,
      contains("_debugFailure('file drop import', stackTrace)"),
    );
    expect(
      source,
      contains('PDF / 動画を取り込めませんでした。もう一度お試しください。'),
    );
    expect(source, isNot(contains('PDF / 動画を取り込めませんでした:')));
    expect(source, contains("_debugFailure('best-effort PDF author creation'"));
    expect(source, isNot(contains('debugPrint(error')));
    expect(source, isNot(contains('debugPrint(\'$error')));
  });
}
