import 'dart:io';

import 'package:bookmark_app/services/primitive_file_import_classifier.dart';
import 'package:bookmark_app/services/primitive_object_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown bytes with image filename route to File exactly once', () async {
    final root = await Directory.systemTemp.createTemp('primitive_unknown_image_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/misleading.png');
    await source.writeAsBytes(const <int>[1, 2, 3, 4, 5, 6, 7, 8]);

    var imageCalls = 0;
    var fileCalls = 0;
    String? forwardedContentType;
    final service = PrimitiveObjectImportService(
      importImage: ({
        required databaseId,
        required sourcePath,
        contentType,
      }) async {
        imageCalls++;
        return 10;
      },
      importFile: ({
        required databaseId,
        required sourcePath,
        contentType,
      }) async {
        fileCalls++;
        forwardedContentType = contentType;
        return 20;
      },
    );

    final result = await service.importPath(
      databaseId: 1,
      sourcePath: source.path,
      declaredContentType: 'application/octet-stream',
    );

    expect(result.objectId, 20);
    expect(result.target, PrimitiveFileImportTarget.file);
    expect(result.evidence, PrimitiveFileImportEvidence.fallback);
    expect(result.contentType, isNull);
    expect(forwardedContentType, isNull);
    expect(imageCalls, 0);
    expect(fileCalls, 1);
  });
}
