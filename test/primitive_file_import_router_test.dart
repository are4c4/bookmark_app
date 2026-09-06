import 'dart:io';

import 'package:bookmark_app/services/primitive_file_import_classifier.dart';
import 'package:bookmark_app/services/primitive_file_import_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = PrimitiveFileImportRouter();

  test('content-classified image invokes only the Image importer', () async {
    final root = await Directory.systemTemp.createTemp('primitive_route_image_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/misleading.pdf');
    await source.writeAsBytes(const <int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      1,
      2,
      3,
    ]);
    var imageCalls = 0;
    var fileCalls = 0;

    final result = await router.importOne(
      sourcePath: source.path,
      declaredContentType: 'application/pdf',
      importImage: (context) async {
        imageCalls++;
        expect(context.sourcePath, source.path);
        expect(context.originalFilename, 'misleading.pdf');
        expect(context.sizeBytes, 11);
        expect(context.classification.target, PrimitiveFileImportTarget.image);
        expect(
          context.classification.evidence,
          PrimitiveFileImportEvidence.content,
        );
        expect(context.classification.contentType, 'image/png');
        return 41;
      },
      importFile: (context) async {
        fileCalls++;
        return 42;
      },
    );

    expect(imageCalls, 1);
    expect(fileCalls, 0);
    expect(result.target, PrimitiveFileImportTarget.image);
    expect(result.objectId, 41);
    expect(result.evidence, PrimitiveFileImportEvidence.content);
    expect(result.contentType, 'image/png');
  });

  test('content-classified PDF invokes only the File importer', () async {
    final root = await Directory.systemTemp.createTemp('primitive_route_file_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/misleading.png');
    await source.writeAsBytes('%PDF-1.7\nbody'.codeUnits);
    var imageCalls = 0;
    var fileCalls = 0;

    final result = await router.importOne(
      sourcePath: source.path,
      declaredContentType: 'image/png',
      importImage: (context) async {
        imageCalls++;
        return 51;
      },
      importFile: (context) async {
        fileCalls++;
        expect(context.classification.target, PrimitiveFileImportTarget.file);
        expect(context.classification.contentType, 'application/pdf');
        return 52;
      },
    );

    expect(imageCalls, 0);
    expect(fileCalls, 1);
    expect(result.target, PrimitiveFileImportTarget.file);
    expect(result.objectId, 52);
    expect(result.contentType, 'application/pdf');
  });

  test('delegate failure never falls back to the other primitive', () async {
    final root = await Directory.systemTemp.createTemp('primitive_route_fail_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/photo.jpg');
    await source.writeAsBytes(const <int>[0xff, 0xd8, 0xff, 0, 1]);
    var imageCalls = 0;
    var fileCalls = 0;

    await expectLater(
      router.importOne(
        sourcePath: source.path,
        importImage: (context) async {
          imageCalls++;
          throw StateError('canonical image import failed');
        },
        importFile: (context) async {
          fileCalls++;
          return 62;
        },
      ),
      throwsStateError,
    );

    expect(imageCalls, 1);
    expect(fileCalls, 0);
  });

  test('meaningful MIME can route unknown bytes without extension guessing',
      () async {
    final root = await Directory.systemTemp.createTemp('primitive_route_mime_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/payload.bin');
    await source.writeAsBytes(const <int>[1, 2, 3, 4]);
    var imageCalls = 0;
    var fileCalls = 0;

    final result = await router.importOne(
      sourcePath: source.path,
      declaredContentType: 'image/jpeg',
      importImage: (context) async {
        imageCalls++;
        return 71;
      },
      importFile: (context) async {
        fileCalls++;
        return 72;
      },
    );

    expect(imageCalls, 1);
    expect(fileCalls, 0);
    expect(result.target, PrimitiveFileImportTarget.image);
    expect(result.evidence, PrimitiveFileImportEvidence.mime);
    expect(result.contentType, 'image/jpeg');
  });

  test('missing source fails before either importer is invoked', () async {
    var imageCalls = 0;
    var fileCalls = 0;

    await expectLater(
      router.importOne(
        sourcePath: '/definitely/missing/image.jpg',
        importImage: (context) async {
          imageCalls++;
          return 81;
        },
        importFile: (context) async {
          fileCalls++;
          return 82;
        },
      ),
      throwsStateError,
    );

    expect(imageCalls, 0);
    expect(fileCalls, 0);
  });

  test('invalid delegate Object id fails instead of attempting another target',
      () async {
    final root = await Directory.systemTemp.createTemp('primitive_route_id_');
    addTearDown(() => root.delete(recursive: true));
    final source = File('${root.path}/archive.zip');
    await source.writeAsBytes(const <int>[0x50, 0x4b, 0x03, 0x04, 1]);
    var imageCalls = 0;
    var fileCalls = 0;

    await expectLater(
      router.importOne(
        sourcePath: source.path,
        importImage: (context) async {
          imageCalls++;
          return 91;
        },
        importFile: (context) async {
          fileCalls++;
          return 0;
        },
      ),
      throwsStateError,
    );

    expect(imageCalls, 0);
    expect(fileCalls, 1);
  });
}
