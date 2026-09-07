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

  test('malformed MIME does not suppress supported image extension fallback', () {
    for (final malformed in <String>[
      'image/',
      '/png',
      'image/png/extra',
      'image / png',
    ]) {
      final classification = classifier.classify(
        filename: 'camera.png',
        declaredContentType: malformed,
      );

      expect(
        classification.target,
        PrimitiveFileImportTarget.image,
        reason: malformed,
      );
      expect(
        classification.evidence,
        PrimitiveFileImportEvidence.extension,
        reason: malformed,
      );
      expect(classification.contentType, 'image/png', reason: malformed);
    }
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

  test('common archives beat misleading image names', () {
    final gzip = classifier.classify(
      filename: 'backup.png',
      headerBytes: const <int>[0x1f, 0x8b, 0x08, 0x00],
    );
    final sevenZip = classifier.classify(
      filename: 'bundle.jpg',
      headerBytes: const <int>[0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c, 0, 4],
    );
    final rar = classifier.classify(
      filename: 'archive.webp',
      headerBytes: const <int>[0x52, 0x61, 0x72, 0x21, 0x1a, 0x07, 0x01, 0x00],
    );

    for (final classification in <PrimitiveFileImportClassification>[
      gzip,
      sevenZip,
      rar,
    ]) {
      expect(classification.target, PrimitiveFileImportTarget.file);
      expect(classification.evidence, PrimitiveFileImportEvidence.content);
    }
    expect(gzip.contentType, 'application/gzip');
    expect(sevenZip.contentType, 'application/x-7z-compressed');
    expect(rar.contentType, 'application/vnd.rar');
  });

  test('common audio and video signatures beat misleading image names', () {
    final mp4 = classifier.classify(
      filename: 'movie.png',
      declaredContentType: 'image/png',
      headerBytes: <int>[
        0, 0, 0, 24,
        ...'ftyp'.codeUnits,
        ...'mp42'.codeUnits,
      ],
    );
    final quickTime = classifier.classify(
      filename: 'clip.jpg',
      headerBytes: <int>[
        0, 0, 0, 24,
        ...'ftyp'.codeUnits,
        ...'qt  '.codeUnits,
      ],
    );
    final wav = classifier.classify(
      filename: 'audio.gif',
      headerBytes: <int>[
        ...'RIFF'.codeUnits,
        0, 0, 0, 0,
        ...'WAVE'.codeUnits,
      ],
    );
    final mp3 = classifier.classify(
      filename: 'track.webp',
      headerBytes: <int>[...'ID3'.codeUnits, 4, 0, 0],
    );

    for (final classification in <PrimitiveFileImportClassification>[
      mp4,
      quickTime,
      wav,
      mp3,
    ]) {
      expect(classification.target, PrimitiveFileImportTarget.file);
      expect(classification.evidence, PrimitiveFileImportEvidence.content);
    }
    expect(mp4.contentType, 'video/mp4');
    expect(quickTime.contentType, 'video/quicktime');
    expect(wav.contentType, 'audio/wav');
    expect(mp3.contentType, 'audio/mpeg');
  });

  test('unsupported image content never falls through to png extension', () {
    final avif = classifier.classify(
      filename: 'future.png',
      headerBytes: <int>[
        0, 0, 0, 24,
        ...'ftyp'.codeUnits,
        ...'avif'.codeUnits,
      ],
    );
    final bmp = classifier.classify(
      filename: 'bitmap.png',
      headerBytes: const <int>[0x42, 0x4d, 0, 0, 0, 0],
    );
    final tiff = classifier.classify(
      filename: 'scan.png',
      headerBytes: const <int>[0x49, 0x49, 0x2a, 0x00, 8, 0, 0, 0],
    );
    final icon = classifier.classify(
      filename: 'icon.png',
      headerBytes: const <int>[0x00, 0x00, 0x01, 0x00, 1, 0],
    );

    for (final classification in <PrimitiveFileImportClassification>[
      avif,
      bmp,
      tiff,
      icon,
    ]) {
      expect(classification.target, PrimitiveFileImportTarget.file);
      expect(classification.evidence, PrimitiveFileImportEvidence.content);
    }
    expect(avif.contentType, 'image/avif');
    expect(bmp.contentType, 'image/bmp');
    expect(tiff.contentType, 'image/tiff');
    expect(icon.contentType, 'image/x-icon');
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
