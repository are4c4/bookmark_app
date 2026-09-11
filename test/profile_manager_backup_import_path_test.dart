import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/services/profile_manager.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late Directory supportDirectory;
  late Directory documentsDirectory;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp(
      'bookmark_profile_backup_import_',
    );
    supportDirectory = Directory('${sandbox.path}/support');
    documentsDirectory = Directory('${sandbox.path}/documents');
    await supportDirectory.create(recursive: true);
    await documentsDirectory.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getTemporaryDirectory') return sandbox.path;
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  Future<ProfileManager> loadManager() => ProfileManager.load(
    applicationSupportDirectoryProvider: () async => supportDirectory,
    applicationDocumentsDirectoryProvider: () async => documentsDirectory,
  );

  Future<File> createLegacyAbsolutePathBackup({
    required Directory source,
    required String vaultId,
    required File externalPhoto,
    required File externalAttachment,
    Map<String, Object?> metadataOverrides = const {},
  }) async {
    final sourcePhoto = File('${source.path}/photos/inside.jpg');
    final relativePhoto = File('${source.path}/photos/already-relative.jpg');
    final sourceAttachment = File('${source.path}/attachments/inside.pdf');
    final relativeAttachment = File(
      '${source.path}/attachments/already-relative.pdf',
    );
    for (final file in [
      sourcePhoto,
      relativePhoto,
      sourceAttachment,
      relativeAttachment,
    ]) {
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3, 4]);
    }

    final missingPhotoPath = '${source.path}/photos/missing.jpg';
    final missingAttachmentPath = '${source.path}/attachments/missing.pdf';

    final database = AppDatabase.forTesting(
      NativeDatabase(File('${source.path}/database.sqlite')),
      profileDirectoryPath: source.path,
    );
    try {
      final bookmarkId = await database.addBookmark(
        url: 'https://example.com/import-paths',
        title: 'Import paths',
      );
      await database
          .into(database.photos)
          .insert(PhotosCompanion.insert(path: sourcePhoto.path));
      await database
          .into(database.photos)
          .insert(PhotosCompanion.insert(path: 'photos/already-relative.jpg'));
      await database
          .into(database.photos)
          .insert(PhotosCompanion.insert(path: missingPhotoPath));
      await database
          .into(database.photos)
          .insert(PhotosCompanion.insert(path: externalPhoto.path));
      await database
          .into(database.bookmarkAttachments)
          .insert(
            BookmarkAttachmentsCompanion.insert(
              bookmarkId: bookmarkId,
              fileName: 'inside.pdf',
              path: sourceAttachment.path,
              kind: const Value('pdf'),
              sizeBytes: const Value(4),
              createdAt: DateTime(2026, 9, 11).toIso8601String(),
            ),
          );
      await database
          .into(database.bookmarkAttachments)
          .insert(
            BookmarkAttachmentsCompanion.insert(
              bookmarkId: bookmarkId,
              fileName: 'already-relative.pdf',
              path: 'attachments/already-relative.pdf',
              kind: const Value('pdf'),
              sizeBytes: const Value(4),
              createdAt: DateTime(2026, 9, 11).toIso8601String(),
            ),
          );
      await database
          .into(database.bookmarkAttachments)
          .insert(
            BookmarkAttachmentsCompanion.insert(
              bookmarkId: bookmarkId,
              fileName: 'missing.pdf',
              path: missingAttachmentPath,
              kind: const Value('pdf'),
              sizeBytes: const Value(4),
              createdAt: DateTime(2026, 9, 11).toIso8601String(),
            ),
          );
      await database
          .into(database.bookmarkAttachments)
          .insert(
            BookmarkAttachmentsCompanion.insert(
              bookmarkId: bookmarkId,
              fileName: 'outside.pdf',
              path: externalAttachment.path,
              kind: const Value('pdf'),
              sizeBytes: const Value(4),
              createdAt: DateTime(2026, 9, 11).toIso8601String(),
            ),
          );
    } finally {
      await database.close();
    }

    await File('${source.path}/profile.json').writeAsString(
      jsonEncode({
        'formatVersion': 1,
        'id': vaultId,
        'name': 'Portable source',
        'database': 'database.sqlite',
        'photos': 'photos',
        'attachments': 'attachments',
        ...metadataOverrides,
      }),
    );

    final archive = File('${sandbox.path}/$vaultId.zip');
    await ZipFileEncoder().zipDirectory(
      source,
      filename: archive.path,
      followLinks: false,
    );
    return archive;
  }

  Future<({List<String> photos, List<String> attachments})> storedPaths(
    DatabaseProfile profile,
  ) async {
    final database = AppDatabase.forTesting(
      NativeDatabase(File('${profile.directoryPath}/database.sqlite')),
      profileDirectoryPath: profile.directoryPath,
    );
    try {
      final photos = await database.select(database.photos).get();
      final attachments = await database
          .select(database.bookmarkAttachments)
          .get();
      return (
        photos: photos.map((row) => row.path).toList()..sort(),
        attachments: attachments.map((row) => row.path).toList()..sort(),
      );
    } finally {
      await database.close();
    }
  }

  test('import rebases legacy managed absolute paths from a registered source Vault', () async {
    final manager = await loadManager();
    final source = Directory('${sandbox.path}/source-vault');
    final external = Directory('${sandbox.path}/external');
    await source.create(recursive: true);
    await external.create(recursive: true);
    final externalPhoto = File('${external.path}/outside.jpg');
    final externalAttachment = File('${external.path}/outside.pdf');
    await externalPhoto.writeAsBytes([9, 8, 7, 6]);
    await externalAttachment.writeAsBytes([6, 7, 8, 9]);

    final archive = await createLegacyAbsolutePathBackup(
      source: source,
      vaultId: 'legacy-source',
      externalPhoto: externalPhoto,
      externalAttachment: externalAttachment,
    );
    await manager.openVault(source.path);

    final imported = await manager.importProfileBackup(
      archive.path,
      name: 'Imported',
    );
    final paths = await storedPaths(imported);

    expect(
      paths.photos,
      containsAll(<String>[
        'photos/already-relative.jpg',
        'photos/inside.jpg',
        '${source.path}/photos/missing.jpg',
        externalPhoto.path,
      ]),
    );
    expect(
      paths.attachments,
      containsAll(<String>[
        'attachments/already-relative.pdf',
        'attachments/inside.pdf',
        '${source.path}/attachments/missing.pdf',
        externalAttachment.path,
      ]),
    );
    expect(
      await File('${imported.directoryPath}/photos/inside.jpg').readAsBytes(),
      [1, 2, 3, 4],
    );
    expect(
      await File('${imported.directoryPath}/attachments/inside.pdf')
          .readAsBytes(),
      [1, 2, 3, 4],
    );
  });

  test('import does not guess a source root from portable metadata', () async {
    final manager = await loadManager();
    final source = Directory('${sandbox.path}/unregistered-source');
    final external = Directory('${sandbox.path}/external-unregistered');
    await source.create(recursive: true);
    await external.create(recursive: true);
    final externalPhoto = File('${external.path}/outside.jpg');
    final externalAttachment = File('${external.path}/outside.pdf');
    await externalPhoto.writeAsBytes([9]);
    await externalAttachment.writeAsBytes([8]);

    final archive = await createLegacyAbsolutePathBackup(
      source: source,
      vaultId: 'unregistered-source',
      externalPhoto: externalPhoto,
      externalAttachment: externalAttachment,
    );

    final imported = await manager.importProfileBackup(
      archive.path,
      name: 'Imported without source',
    );
    final paths = await storedPaths(imported);

    expect(paths.photos, contains('${source.path}/photos/inside.jpg'));
    expect(paths.photos, contains('${source.path}/photos/missing.jpg'));
    expect(
      paths.attachments,
      contains('${source.path}/attachments/inside.pdf'),
    );
    expect(
      paths.attachments,
      contains('${source.path}/attachments/missing.pdf'),
    );
    expect(paths.photos, contains('photos/already-relative.jpg'));
    expect(paths.attachments, contains('attachments/already-relative.pdf'));
    expect(paths.photos, contains(externalPhoto.path));
    expect(paths.attachments, contains(externalAttachment.path));
  });

  test('malformed portable metadata cannot authorize path rewriting', () async {
    final manager = await loadManager();
    final source = Directory('${sandbox.path}/malformed-source');
    final external = Directory('${sandbox.path}/external-malformed');
    await source.create(recursive: true);
    await external.create(recursive: true);
    final externalPhoto = File('${external.path}/outside.jpg');
    final externalAttachment = File('${external.path}/outside.pdf');
    await externalPhoto.writeAsBytes([9]);
    await externalAttachment.writeAsBytes([8]);

    final archive = await createLegacyAbsolutePathBackup(
      source: source,
      vaultId: 'malformed-source',
      externalPhoto: externalPhoto,
      externalAttachment: externalAttachment,
      metadataOverrides: const {'photos': '../photos'},
    );
    await manager.openVault(source.path);

    final imported = await manager.importProfileBackup(
      archive.path,
      name: 'Imported malformed metadata',
    );
    final paths = await storedPaths(imported);

    expect(paths.photos, contains('${source.path}/photos/inside.jpg'));
    expect(
      paths.attachments,
      contains('${source.path}/attachments/inside.pdf'),
    );
    expect(paths.photos, contains('photos/already-relative.jpg'));
    expect(paths.attachments, contains('attachments/already-relative.pdf'));
    expect(paths.photos, contains(externalPhoto.path));
    expect(paths.attachments, contains(externalAttachment.path));
  });
}
