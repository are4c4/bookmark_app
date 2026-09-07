import 'dart:io';

import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late Directory vault;
  late Directory photos;
  late PhotoStorageService storage;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('photo_safe_delete_');
    vault = Directory('${sandbox.path}/Vault');
    photos = Directory('${vault.path}/photos');
    await photos.create(recursive: true);
    storage = PhotoStorageService(photoDirectoryPath: photos.path);
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('deletes a managed Photo and its paired original backup', () async {
    final photo = File('${photos.path}/managed.jpg');
    final backup = File('${photo.path}.bookmark_original');
    await photo.writeAsBytes(const <int>[1, 2, 3]);
    await backup.writeAsBytes(const <int>[4, 5, 6]);

    await storage.deleteManagedPhoto(photo.path);

    expect(photo.existsSync(), isFalse);
    expect(backup.existsSync(), isFalse);
  });

  test('resolves a portable relative Photo path through the Vault root',
      () async {
    final photo = File('${photos.path}/relative.png');
    await photo.writeAsBytes(const <int>[7, 8, 9]);

    await storage.deleteManagedPhoto('photos/relative.png');

    expect(photo.existsSync(), isFalse);
  });

  test('preserves external absolute Photo paths and external backups', () async {
    final external = File('${sandbox.path}/external.jpg');
    final externalBackup = File('${external.path}.bookmark_original');
    await external.writeAsString('external');
    await externalBackup.writeAsString('external backup');

    await storage.deleteManagedPhoto(external.path);

    expect(await external.readAsString(), 'external');
    expect(await externalBackup.readAsString(), 'external backup');
  });

  test('preserves traversal paths that would escape photos', () async {
    final outside = File('${vault.path}/outside.jpg');
    await outside.writeAsString('keep');

    await storage.deleteManagedPhoto('photos/../outside.jpg');

    expect(await outside.readAsString(), 'keep');
  });

  test('preserves symbolic-link Photo targets', () async {
    if (Platform.isWindows) return;

    final external = File('${sandbox.path}/external-target.jpg');
    await external.writeAsString('keep target');
    final link = Link('${photos.path}/linked.jpg');
    await link.create(external.path);

    await storage.deleteManagedPhoto('photos/linked.jpg');

    expect(await external.readAsString(), 'keep target');
    expect(await link.target(), external.path);
  });

  test('preserves nested paths through a symbolic-link directory', () async {
    if (Platform.isWindows) return;

    final outside = Directory('${sandbox.path}/Outside');
    await outside.create();
    final external = File('${outside.path}/escaped.jpg');
    await external.writeAsString('keep escaped');
    final linkedDirectory = Link('${photos.path}/linked-dir');
    await linkedDirectory.create(outside.path);

    await storage.deleteManagedPhoto('photos/linked-dir/escaped.jpg');

    expect(await external.readAsString(), 'keep escaped');
    expect(await linkedDirectory.target(), outside.path);
  });

  test('refuses a symbolic-link photos root', () async {
    if (Platform.isWindows) return;

    await photos.delete(recursive: true);
    final outside = Directory('${sandbox.path}/Outside Photos');
    await outside.create();
    final external = File('${outside.path}/photo.jpg');
    await external.writeAsString('keep root target');
    final photosLink = Link(photos.path);
    await photosLink.create(outside.path);

    await storage.deleteManagedPhoto('photos/photo.jpg');

    expect(await external.readAsString(), 'keep root target');
    expect(await photosLink.target(), outside.path);
  });

  test('missing managed Photo is idempotent and may clean its safe backup',
      () async {
    final missing = File('${photos.path}/missing.jpg');
    final backup = File('${missing.path}.bookmark_original');
    await backup.writeAsString('managed backup');

    await storage.deleteManagedPhoto('photos/missing.jpg');
    await storage.deleteManagedPhoto('photos/missing.jpg');

    expect(missing.existsSync(), isFalse);
    expect(backup.existsSync(), isFalse);
  });

  test('does not recreate an unavailable Vault while deleting', () async {
    final unavailableVault = Directory('${sandbox.path}/Unavailable Vault');
    final unavailablePhotos = '${unavailableVault.path}/photos';
    final unavailableStorage = PhotoStorageService(
      photoDirectoryPath: unavailablePhotos,
    );

    await unavailableStorage.deleteManagedPhoto('photos/missing.jpg');

    expect(unavailableVault.existsSync(), isFalse);
  });

  test('preserves the managed file if its backup path is a symlink', () async {
    if (Platform.isWindows) return;

    final photo = File('${photos.path}/paired.jpg');
    await photo.writeAsString('managed photo');
    final external = File('${sandbox.path}/external-backup.jpg');
    await external.writeAsString('external backup');
    final backupLink = Link('${photo.path}.bookmark_original');
    await backupLink.create(external.path);

    await storage.deleteManagedPhoto('photos/paired.jpg');

    expect(await photo.readAsString(), 'managed photo');
    expect(await external.readAsString(), 'external backup');
    expect(await backupLink.target(), external.path);
  });

  test('preserves non-file entities inside managed photos', () async {
    final directoryTarget = Directory('${photos.path}/folder.jpg');
    await directoryTarget.create();

    await storage.deleteManagedPhoto('photos/folder.jpg');

    expect(directoryTarget.existsSync(), isTrue);
  });
}
