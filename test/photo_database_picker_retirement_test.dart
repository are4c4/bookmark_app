import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy Photo database picker stays retired from production', () {
    expect(File('lib/widgets/photo_database_picker.dart').existsSync(), isFalse);

    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('showPhotoDatabasePicker')),
        reason: 'Legacy Photo picker call returned in ${file.path}',
      );
      expect(
        source,
        isNot(contains('photo_database_picker.dart')),
        reason: 'Legacy Photo picker import returned in ${file.path}',
      );
      expect(
        source,
        isNot(contains('PhotoPickerResult')),
        reason: 'Legacy Photo picker result type returned in ${file.path}',
      );
    }
  });
}
