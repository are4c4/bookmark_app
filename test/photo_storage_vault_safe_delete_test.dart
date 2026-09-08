import 'dart:io';

import 'package:bookmark_app/services/photo_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deletes managed Photo and regular original backup inside active root',
      () async {
    final vault = await Directory.systemTemp.createTemp('photo_safe_delete_');
    addTearDown(() => vault.delete(recursive: true));
    final photos = Directory('${vault.path}/photos');
    await photos.create();
    final managed = File('${photos.path}/managed.jpg');
    final backup = File('${managed.path}.bookmark_original');
    await managed.writeAsBytes(const <int>[1, 2, 3]);
    await backup.writeAsBytes(const <int>[4, 5, 6]);

    final storage = PhotoStorageService(photoDirectoryPath: photos.path);
    await storage.deleteManagedPhoto('photos/managed.jpg');

    expect(await managed.exists(), isFalse);
    expect(await backup.exists(), isFalse);
  });

  test('preserves external absolute Photo paths', () async {
    final root = await Directory.systemTemp.createTemp('photo_external_delete_');
    addTearDown(() => root.delete(recursive: true));
    final vault = Directory('${root.path}/vault');
    final photos = Directory('${vault.path}/photos');
    await photos.create(recursive: true);
    final external = File('${root.path}/external.jpg');
    await external.writeAsBytes(const <int>[1]);

    final storage = PhotoStorageService(photoDirectoryPath: photos.path);
    await storage.deleteManagedPhoto(external.path);

    expect(await external.exists(), isTrue);
  });

  test('preserves traversal paths even when they resolve to an existing file',
      () async {
    final vault = await Directory.systemTemp.createTemp('photo_traversal_delete_');
    addTearDown(() => vault.delete(recursive: true));
    final photos = Directory('${vault.path}/photos');
    await photos.create();
    final outside = File('${vault.path}/outside.jpg');
    await outside.writeAsBytes(const <int>[1]);

    final storage = PhotoStorageService(photoDirectoryPath: photos.path);
    await storage.deleteManagedPhoto('photos/../outside.jpg');

    expect(await outside.exists(), isTrue);
  });

  test(
    'preserves a symlink Photo target inside the managed root',
    () async {
      final root = await Directory.systemTemp.createTemp('photo_link_delete_');
      addTearDown(() => root.delete(recursive: true));
      final vault = Directory('${root.path}/vault');
      final photos = Directory('${vault.path}/photos');
      await photos.create(recursive: true);
      final external = File('${root.path}/external.jpg');
      await external.writeAsBytes(const <int>[7, 8]);
      final link = Link('${photos.path}/linked.jpg');
      await link.create(external.path);

      final storage = PhotoStorageService(photoDirectoryPath: photos.path);
      await storage.deleteManagedPhoto('photos/linked.jpg');

      expect(await link.exists(), isTrue);
      expect(await external.exists(), isTrue);
    },
    skip: Platform.isWindows,
  );

  test(
    'preserves files when the configured photos root itself is a symlink',
    () async {
      final root = await Directory.systemTemp.createTemp('photo_root_link_');
      addTearDown(() => root.delete(recursive: true));
      final vault = Directory('${root.path}/vault');
      await vault.create();
      final realPhotos = Directory('${root.path}/real_photos');
      await realPhotos.create();
      final managed = File('${realPhotos.path}/managed.jpg');
      await managed.writeAsBytes(const <int>[9]);
      final photosLink = Link('${vault.path}/photos');
      await photosLink.create(realPhotos.path);

      final storage = PhotoStorageService(photoDirectoryPath: photosLink.path);
      await storage.deleteManagedPhoto('photos/managed.jpg');

      expect(await managed.exists(), isTrue);
      expect(await photosLink.exists(), isTrue);
    },
    skip: Platform.isWindows,
  );

  test('offline moved Vault root is not recreated during deletion', () async {
    final root = await Directory.systemTemp.createTemp('photo_offline_delete_');
    addTearDown(() => root.delete(recursive: true));
    final oldVault = Directory('${root.path}/old_vault');
    final oldPhotos = Directory('${oldVault.path}/photos');
    await oldPhotos.create(recursive: true);
    final oldManaged = File('${oldPhotos.path}/managed.jpg');
    await oldManaged.writeAsBytes(const <int>[1, 2]);

    final movedVault = Directory('${root.path}/moved_vault');
    await movedVault.create();
    final missingPhotos = Directory('${movedVault.path}/photos');
    final storage = PhotoStorageService(photoDirectoryPath: missingPhotos.path);
    await storage.deleteManagedPhoto('photos/managed.jpg');

    expect(await missingPhotos.exists(), isFalse);
    expect(await oldManaged.exists(), isTrue);
  });

  test('missing managed Photo is idempotent', () async {
    final vault = await Directory.systemTemp.createTemp('photo_missing_delete_');
    addTearDown(() => vault.delete(recursive: true));
    final photos = Directory('${vault.path}/photos');
    await photos.create();

    final storage = PhotoStorageService(photoDirectoryPath: photos.path);
    await storage.deleteManagedPhoto('photos/missing.jpg');
    await storage.deleteManagedPhoto('photos/missing.jpg');

    expect(await photos.exists(), isTrue);
    expect(await File('${photos.path}/missing.jpg').exists(), isFalse);
  });

  test(
    'unsafe original-backup symlink is preserved while managed Photo is deleted',
    () async {
      final root = await Directory.systemTemp.createTemp('photo_backup_link_');
      addTearDown(() => root.delete(recursive: true));
      final vault = Directory('${root.path}/vault');
      final photos = Directory('${vault.path}/photos');
      await photos.create(recursive: true);
      final managed = File('${photos.path}/managed.jpg');
      await managed.writeAsBytes(const <int>[1, 2, 3]);
      final external = File('${root.path}/external-original.jpg');
      await external.writeAsBytes(const <int>[4, 5, 6]);
      final backupLink = Link('${managed.path}.bookmark_original');
      await backupLink.create(external.path);

      final storage = PhotoStorageService(photoDirectoryPath: photos.path);
      await storage.deleteManagedPhoto('photos/managed.jpg');

      expect(await managed.exists(), isFalse);
      expect(await backupLink.exists(), isTrue);
      expect(await external.exists(), isTrue);
    },
    skip: Platform.isWindows,
  );
}
