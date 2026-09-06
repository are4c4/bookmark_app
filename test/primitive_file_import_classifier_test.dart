import 'dart:io';

import 'package:bookmark_app/services/primitive_file_import_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classifier = PrimitiveFileImportClassifier();

  test('content signature overrides conflicting filename extension', () {
    final png = classifier.classify(
      filename: 'document.pdf',
      declaredContentType: 'application/pdf',
      headerBytes: const <int>[
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
      ],
    );
    final pdf = classifier.classify(
      filename: 'photo.png',
      declaredContentType: 'image/png',
      headerBytes: '%PDF-1.7'.codeUnits,
    );

    expect(png.target, PrimitiveFileImportTarget.image);
    expect(png.evidence, PrimitiveFileImportEvidence.content);
    expect(png.contentType, 'image/png');
    expect(pdf.target, PrimitiveFileImportTarget.file);
    expect(pdf.evidence, PrimitiveFileImportEvidence.content);
    expect(pdf.contentType, 'application/pdf');
  });

  test('meaningful MIME overrides extension when content is unknown', () {
    final declaredFile = classifier.classify(
      filename: 'misleading.png',
      declaredContentType: 'application/pdf; charset=binary',
    );
    final declaredImage = classifier.classify(
      filename: 'misleading.pdf',
      declaredContentType: 'IMAGE/JPEG',
    );

    expect(declaredFile.target, PrimitiveFileImportTarget.file);
    expect(declaredFile.evidence, PrimitiveFileImportEvidence.mime);
    expect(declaredFile.contentType, 'application/pdf');
    expect(declaredImage.target, PrimitiveFileImportTarget.image);
    expect(declaredImage.evidence, PrimitiveFileImportEvidence.mime);
    expect(declaredImage.contentType, 'image/jpeg');
  });

  test('generic MIME permits supported image extension fallback', () {
    final classification = classifier.classify(
      filename: 'camera.HEIC',
      declaredContentType: 'application/octet-stream',
    );

    expect(classification.target, PrimitiveFileImportTarget.image);
    expect(classification.evidence, PrimitiveFileImportEvidence.extension);
    expect(classification.contentType, 'image/heic');
  });

  test('unsupported image MIME remains a generic File', () {
    final classification = classifier.classify(
      filename: 'vector.svg',
      declaredContentType: 'image/svg+xml',
    );

    expect(classification.target, PrimitiveFileImportTarget.file);
    expect(classification.evidence, PrimitiveFileImportEvidence.mime);
    expect(classification.contentType, 'image/svg+xml');
  });

  test('unknown content and extension conservatively route to File', () {
    final classification = classifier.classify(filename: 'README');

    expect(classification.target, PrimitiveFileImportTarget.file);
    expect(classification.evidence, PrimitiveFileImportEvidence.fallback);
    expect(classification.contentType, isNull);
  });

  test('HEIC and ZIP signatures beat misleading names', () {
    final heic = classifier.classify(
      filename: 'image.zip',
      headerBytes: <int>[
        0, 0, 0, 24,
        ...'ftyp'.codeUnits,
        ...'heic'.codeUnits,
      ],
    );
    final zip = classifier.classify(
      filename: 'archive.jpg',
      headerBytes: const <int>[0x50, 0x4b, 0x03, 0x04, 1, 2, 3],
    );

    expect(heic.target, PrimitiveFileImportTarget.image);
    expect(heic.contentType, 'image/heic');
    expect(zip.target, PrimitiveFileImportTarget.file);
    expect(zip.contentType, 'application/zip');
  });

  test('path classifier reads only enough bytes to identify content', () async {
    final root = await Directory.systemTemp.createTemp('primitive_classifier_');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/not-an-image.png');
    await file.writeAsBytes(<int>[
      ...'%PDF-1.7\n'.codeUnits,
      ...List<int>.filled(128, 0),
    ]);

    final classification = await classifier.classifyPath(path: file.path);

    expect(classification.target, PrimitiveFileImportTarget.file);
    expect(classification.evidence, PrimitiveFileImportEvidence.content);
    expect(classification.contentType, 'application/pdf');
  });
}
