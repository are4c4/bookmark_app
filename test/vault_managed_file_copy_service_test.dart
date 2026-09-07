import 'dart:io';

import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/services/vault_managed_file_copy_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late Directory vault;
  late VaultManagedFileCopyService service;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('bookmark_managed_copy_');
    vault = Directory('${sandbox.path}/Vault');
    await vault.create(recursive: true);
    service = VaultManagedFileCopyService();
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('copies an arbitrary regular file into portable Vault storage', () async {
    final source = File('${sandbox.path}/research notes.docx');
    final bytes = <int>[1, 2, 3, 4, 5, 6];
    await source.writeAsBytes(bytes);

    final copy = await service.copyIntoVault(
      sourcePath: source.path,
      vaultDirectoryPath: vault.path,
    );

    expect(copy.ownership, VaultManagedFileOwnership.vaultManagedCopy);
    expect(copy.ownership.storageKey, 'vault-managed-copy-v1');
    expect(copy.originalFilename, 'research notes.docx');
    expect(copy.sizeBytes, bytes.length);
    expect(copy.storedPath, startsWith('attachments/'));
    expect(copy.storedPath, endsWith('_research notes.docx'));
    expect(copy.storedPath.startsWith('/'), isFalse);
    expect(
      File(copy.resolvedPath).absolute.path,
      File(
        ProfilePathResolver(vault.absolute.path)
            .resolveStoredPath(copy.storedPath),
      ).absolute.path,
    );
    expect(await File(copy.resolvedPath).readAsBytes(), bytes);
    expect(await source.readAsBytes(), bytes);
  });

  test('same source filename never overwrites an earlier managed copy', () async {
    final source = File('${sandbox.path}/paper.pdf');
    await source.writeAsString('first');

    final first = await service.copyIntoVault(
      sourcePath: source.path,
      vaultDirectoryPath: vault.path,
    );
    await source.writeAsString('second');
    final second = await service.copyIntoVault(
      sourcePath: source.path,
      vaultDirectoryPath: vault.path,
    );

    expect(second.resolvedPath, isNot(first.resolvedPath));
    expect(await File(first.resolvedPath).readAsString(), 'first');
    expect(await File(second.resolvedPath).readAsString(), 'second');
  });

  test('rollback removes only the managed copy and preserves the source', () async {
    final source = File('${sandbox.path}/archive.zip');
    await source.writeAsString('source bytes');
    final copy = await service.copyIntoVault(
      sourcePath: source.path,
      vaultDirectoryPath: vault.path,
    );

    await service.rollbackCopy(copy);
    await service.rollbackCopy(copy);

    expect(File(copy.resolvedPath).existsSync(), isFalse);
    expect(await source.readAsString(), 'source bytes');
    expect(Directory('${vault.path}/attachments').existsSync(), isTrue);
  });

  test('rejects missing and non-file sources without creating managed bytes',
      () async {
    final sourceDirectory = Directory('${sandbox.path}/folder');
    await sourceDirectory.create();

    await expectLater(
      service.copyIntoVault(
        sourcePath: '${sandbox.path}/missing.bin',
        vaultDirectoryPath: vault.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      service.copyIntoVault(
        sourcePath: sourceDirectory.path,
        vaultDirectoryPath: vault.path,
      ),
      throwsA(isA<FileSystemException>()),
    );

    final attachments = Directory('${vault.path}/attachments');
    expect(
      attachments.existsSync()
          ? await attachments.list().toList()
          : const <FileSystemEntity>[],
      isEmpty,
    );
  });

  test('fails closed when the attachments location is not a directory',
      () async {
    final source = File('${sandbox.path}/paper.txt');
    await source.writeAsString('source');
    final blocker = File('${vault.path}/attachments');
    await blocker.writeAsString('do not replace');

    await expectLater(
      service.copyIntoVault(
        sourcePath: source.path,
        vaultDirectoryPath: vault.path,
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await blocker.readAsString(), 'do not replace');
    expect(await source.readAsString(), 'source');
  });

  test('does not create a missing Vault root while importing', () async {
    final source = File('${sandbox.path}/file.bin');
    await source.writeAsBytes(const <int>[9, 8, 7]);
    final missingVault = Directory('${sandbox.path}/Missing Vault');

    await expectLater(
      service.copyIntoVault(
        sourcePath: source.path,
        vaultDirectoryPath: missingVault.path,
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(missingVault.existsSync(), isFalse);
    expect(await source.readAsBytes(), const <int>[9, 8, 7]);
  });
}
