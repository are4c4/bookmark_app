import 'dart:io';

import 'package:bookmark_app/services/primitive_file_import_classifier.dart';
import 'package:bookmark_app/services/primitive_object_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrimitiveObjectImportService', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'primitive_object_import_service_test_',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('content signature routes disguised PDF to File only', () async {
      final source = File('${tempDirectory.path}/photo.jpg');
      await source.writeAsBytes('%PDF-1.7\n'.codeUnits);

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
        databaseId: 7,
        sourcePath: source.path,
        declaredContentType: 'image/jpeg',
      );

      expect(result.objectId, 20);
      expect(result.target, PrimitiveFileImportTarget.file);
      expect(result.evidence, PrimitiveFileImportEvidence.content);
      expect(result.contentType, 'application/pdf');
      expect(forwardedContentType, 'application/pdf');
      expect(imageCalls, 0);
      expect(fileCalls, 1);
    });

    test('content signature routes disguised MP4 to File only', () async {
      final source = File('${tempDirectory.path}/movie.png');
      await source.writeAsBytes(<int>[
        0, 0, 0, 24,
        ...'ftyp'.codeUnits,
        ...'mp42'.codeUnits,
      ]);

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
          return 25;
        },
        importFile: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          fileCalls++;
          forwardedContentType = contentType;
          return 26;
        },
      );

      final result = await service.importPath(
        databaseId: 8,
        sourcePath: source.path,
        declaredContentType: 'image/png',
      );

      expect(result.objectId, 26);
      expect(result.target, PrimitiveFileImportTarget.file);
      expect(result.evidence, PrimitiveFileImportEvidence.content);
      expect(result.contentType, 'video/mp4');
      expect(forwardedContentType, 'video/mp4');
      expect(imageCalls, 0);
      expect(fileCalls, 1);
    });

    test('content signature routes disguised PNG to Image only', () async {
      final source = File('${tempDirectory.path}/document.pdf');
      await source.writeAsBytes(const <int>[
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]);

      var imageCalls = 0;
      var fileCalls = 0;
      final service = PrimitiveObjectImportService(
        importImage: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          imageCalls++;
          expect(databaseId, 3);
          expect(sourcePath, source.path);
          expect(contentType, 'image/png');
          return 31;
        },
        importFile: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          fileCalls++;
          return 32;
        },
      );

      final result = await service.importPath(
        databaseId: 3,
        sourcePath: source.path,
        declaredContentType: 'application/pdf',
      );

      expect(result.objectId, 31);
      expect(result.target, PrimitiveFileImportTarget.image);
      expect(imageCalls, 1);
      expect(fileCalls, 0);
    });

    test('selected importer failure never falls through to other primitive', () async {
      final source = File('${tempDirectory.path}/image.png');
      await source.writeAsBytes(const <int>[
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]);

      var fileCalls = 0;
      final service = PrimitiveObjectImportService(
        importImage: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          throw StateError('image import failed');
        },
        importFile: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          fileCalls++;
          return 99;
        },
      );

      await expectLater(
        service.importPath(databaseId: 1, sourcePath: source.path),
        throwsStateError,
      );
      expect(fileCalls, 0);
    });

    test('missing source fails before either importer is invoked', () async {
      var imageCalls = 0;
      var fileCalls = 0;
      final service = PrimitiveObjectImportService(
        importImage: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          imageCalls++;
          return 41;
        },
        importFile: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          fileCalls++;
          return 42;
        },
      );

      await expectLater(
        service.importPath(
          databaseId: 1,
          sourcePath: '${tempDirectory.path}/missing.jpg',
        ),
        throwsStateError,
      );
      expect(imageCalls, 0);
      expect(fileCalls, 0);
    });

    test('non-positive Object id fails without alternate primitive retry', () async {
      final source = File('${tempDirectory.path}/archive.zip');
      await source.writeAsBytes(const <int>[0x50, 0x4b, 0x03, 0x04]);
      var imageCalls = 0;
      var fileCalls = 0;
      final service = PrimitiveObjectImportService(
        importImage: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          imageCalls++;
          return 51;
        },
        importFile: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          fileCalls++;
          return 0;
        },
      );

      await expectLater(
        service.importPath(databaseId: 1, sourcePath: source.path),
        throwsStateError,
      );
      expect(imageCalls, 0);
      expect(fileCalls, 1);
    });

    test('multi-file action routes every source exactly once in source order', () async {
      final imageSource = File('${tempDirectory.path}/first.png');
      await imageSource.writeAsBytes(const <int>[
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]);
      final fileSource = File('${tempDirectory.path}/second.bin');
      await fileSource.writeAsBytes('%PDF-1.7\n'.codeUnits);
      final fallbackSource = File('${tempDirectory.path}/third.zip');
      await fallbackSource.writeAsBytes(const <int>[0x50, 0x4b, 0x03, 0x04]);

      final calls = <String>[];
      var nextId = 100;
      final service = PrimitiveObjectImportService(
        importImage: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          calls.add('image:$sourcePath:$contentType');
          return nextId++;
        },
        importFile: ({
          required databaseId,
          required sourcePath,
          contentType,
        }) async {
          calls.add('file:$sourcePath:$contentType');
          return nextId++;
        },
      );

      final results = await service.importPaths(
        databaseId: 11,
        sourcePaths: <String>[
          imageSource.path,
          fileSource.path,
          fallbackSource.path,
        ],
      );

      expect(
        results.map((result) => result.objectId),
        orderedEquals(const <int>[100, 101, 102]),
      );
      expect(
        results.map((result) => result.target),
        orderedEquals(const <PrimitiveFileImportTarget>[
          PrimitiveFileImportTarget.image,
          PrimitiveFileImportTarget.file,
          PrimitiveFileImportTarget.file,
        ]),
      );
      expect(calls, hasLength(3));
      expect(calls[0], startsWith('image:${imageSource.path}:image/png'));
      expect(calls[1], startsWith('file:${fileSource.path}:application/pdf'));
      expect(calls[2], startsWith('file:${fallbackSource.path}:application/zip'));
    });
  });
}
