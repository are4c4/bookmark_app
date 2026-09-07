import 'dart:io';

import 'package:bookmark_app/services/vault_managed_file_copy_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owned delete fails closed when the Vault root is unavailable', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'bookmark_managed_delete_offline_',
    );
    try {
      final missingVault = Directory('${sandbox.path}/Offline Vault');
      final service = VaultManagedFileCopyService();

      await expectLater(
        service.deleteOwnedCopy(
          storedPath: 'attachments/file.bin',
          vaultDirectoryPath: missingVault.path,
          ownershipStorageKey:
              VaultManagedFileOwnership.vaultManagedCopy.storageKey,
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(missingVault.existsSync(), isFalse);
    } finally {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    }
  });
}
