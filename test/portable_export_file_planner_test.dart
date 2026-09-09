import 'dart:io';

import 'package:bookmark_app/domain/managed_file_ownership.dart';
import 'package:bookmark_app/services/portable_export_file_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory sandbox;
  late Directory vault;
  late PortableExportFilePlanner planner;
  const packagePaths = PortableExportPackagePathPolicy();

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('bookmark_portable_export_');
    vault = Directory('${sandbox.path}/Vault');
    await Directory('${vault.path}/attachments').create(recursive: true);
    planner = const PortableExportFilePlanner();
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('safe package member resolves below the selected package root', () async {
    final packageRoot = Directory('${sandbox.path}/Export Package');
    final resolved = packagePaths.resolve(
      packageRootPath: packageRoot.path,
      packageRelativePath: 'attachments/papers/research.pdf',
    );

    final normalizedRoot = packageRoot.absolute.path.replaceAll('\\', '/');
    expect(
      resolved,
      '$normalizedRoot/attachments/papers/research.pdf',
    );
    expect(packageRoot.existsSync(), isFalse);
  });

  test('package path policy rejects ambiguous and escaping members', () {
    for (final unsafePath in <String>[
      '/tmp/file.pdf',
      r'C:/Users/example/file.pdf',
      r'C:\Users\example\file.pdf',
      'attachments/../database.sqlite',
      './attachments/file.pdf',
      'attachments//file.pdf',
      'attachments/file.pdf/',
      r'attachments\..\database.sqlite',
      'attachments/\u0000file.pdf',
    ]) {
      expect(
        () => packagePaths.validateRelativePath(unsafePath),
        throwsA(anyOf(isA<StateError>(), isA<ArgumentError>())),
        reason: unsafePath,
      );
    }
  });

  test('explicit managed ownership plans only the existing Vault copy', () async {
    final managedDirectory = Directory('${vault.path}/attachments/papers');
    await managedDirectory.create();
    final managed = File('${managedDirectory.path}/paper.pdf');
    const bytes = <int>[1, 3, 3, 7];
    await managed.writeAsBytes(bytes);

    final plan = await planner.plan(
      storedPath: 'attachments/papers/paper.pdf',
      ownershipStorageKey: ManagedFileOwnership.vaultManagedCopy.storageKey,
      vaultDirectoryPath: vault.path,
    );

    expect(plan.disposition, PortableExportFileDisposition.managedIncluded);
    expect(plan.includeBytes, isTrue);
    expect(plan.referencePath, 'attachments/papers/paper.pdf');
    expect(plan.packageRelativePath, 'attachments/papers/paper.pdf');
    expect(plan.managedSourcePath, managed.absolute.path);
    expect(
      plan.ownershipStorageKey,
      ManagedFileOwnership.vaultManagedCopy.storageKey,
    );
    expect(await managed.readAsBytes(), bytes);
  });

  test('unowned relative path is not guessed to be managed', () async {
    final managed = File('${vault.path}/attachments/unowned.pdf');
    await managed.writeAsString('keep');

    await expectLater(
      planner.plan(
        storedPath: 'attachments/unowned.pdf',
        ownershipStorageKey: null,
        vaultDirectoryPath: vault.path,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await managed.readAsString(), 'keep');
  });

  test('unknown ownership does not fall back to path inference', () async {
    final managed = File('${vault.path}/attachments/future.bin');
    await managed.writeAsString('future');

    await expectLater(
      planner.plan(
        storedPath: 'attachments/future.bin',
        ownershipStorageKey: 'future-managed-v2',
        vaultDirectoryPath: vault.path,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await managed.readAsString(), 'future');
  });

  test(
    'managed plan rejects traversal absolute and non-attachment paths',
    () async {
      final outside = File('${vault.path}/database.sqlite');
      await outside.writeAsString('database');

      for (final unsafePath in <String>[
        'attachments/../database.sqlite',
        outside.absolute.path,
        'photos/image.jpg',
        r'attachments\file.pdf',
      ]) {
        await expectLater(
          planner.plan(
            storedPath: unsafePath,
            ownershipStorageKey:
                ManagedFileOwnership.vaultManagedCopy.storageKey,
            vaultDirectoryPath: vault.path,
          ),
          throwsA(isA<StateError>()),
        );
      }

      expect(await outside.readAsString(), 'database');
    },
  );

  test(
    'managed plan fails closed for offline missing and non-file sources',
    () async {
      final missingVault = Directory('${sandbox.path}/Missing Vault');
      await expectLater(
        planner.plan(
          storedPath: 'attachments/missing.pdf',
          ownershipStorageKey: ManagedFileOwnership.vaultManagedCopy.storageKey,
          vaultDirectoryPath: missingVault.path,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(missingVault.existsSync(), isFalse);

      await expectLater(
        planner.plan(
          storedPath: 'attachments/missing.pdf',
          ownershipStorageKey: ManagedFileOwnership.vaultManagedCopy.storageKey,
          vaultDirectoryPath: vault.path,
        ),
        throwsA(isA<FileSystemException>()),
      );

      final folder = Directory('${vault.path}/attachments/folder');
      await folder.create();
      await expectLater(
        planner.plan(
          storedPath: 'attachments/folder',
          ownershipStorageKey: ManagedFileOwnership.vaultManagedCopy.storageKey,
          vaultDirectoryPath: vault.path,
        ),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test('managed plan refuses symlinked path components', () async {
    if (Platform.isWindows) return;

    final outsideDirectory = Directory('${sandbox.path}/Outside');
    await outsideDirectory.create();
    final outside = File('${outsideDirectory.path}/outside.bin');
    await outside.writeAsString('outside');

    final nestedLink = Link('${vault.path}/attachments/nested');
    await nestedLink.create(outsideDirectory.path);
    await expectLater(
      planner.plan(
        storedPath: 'attachments/nested/outside.bin',
        ownershipStorageKey: ManagedFileOwnership.vaultManagedCopy.storageKey,
        vaultDirectoryPath: vault.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
    await nestedLink.delete();
    expect(await outside.readAsString(), 'outside');

    final sourceLink = Link('${vault.path}/attachments/link.bin');
    await sourceLink.create(outside.path);
    await expectLater(
      planner.plan(
        storedPath: 'attachments/link.bin',
        ownershipStorageKey: ManagedFileOwnership.vaultManagedCopy.storageKey,
        vaultDirectoryPath: vault.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await outside.readAsString(), 'outside');

    await sourceLink.delete();
    await Directory('${vault.path}/attachments').delete();
    final attachmentsLink = Link('${vault.path}/attachments');
    await attachmentsLink.create(outsideDirectory.path);
    await expectLater(
      planner.plan(
        storedPath: 'attachments/outside.bin',
        ownershipStorageKey: ManagedFileOwnership.vaultManagedCopy.storageKey,
        vaultDirectoryPath: vault.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await outside.readAsString(), 'outside');
  });

  test(
    'external absolute reference stays reference-only without filesystem probe',
    () async {
      final externalPath = '${sandbox.path}/does-not-exist/external.pdf';
      expect(File(externalPath).existsSync(), isFalse);

      final plan = await planner.plan(
        storedPath: File(externalPath).absolute.path,
        ownershipStorageKey: null,
        vaultDirectoryPath: '${sandbox.path}/also-missing-vault',
      );

      expect(plan.disposition, PortableExportFileDisposition.externalReference);
      expect(plan.includeBytes, isFalse);
      expect(plan.referencePath, File(externalPath).absolute.path);
      expect(plan.managedSourcePath, isNull);
      expect(plan.packageRelativePath, isNull);
      expect(plan.ownershipStorageKey, isNull);
      expect(File(externalPath).existsSync(), isFalse);
    },
  );

  test('Windows absolute reference also stays external on every host', () async {
    const externalPath = r'C:\Users\example\external.pdf';

    final plan = await planner.plan(
      storedPath: externalPath,
      ownershipStorageKey: null,
      vaultDirectoryPath: '${sandbox.path}/missing-vault',
    );

    expect(plan.disposition, PortableExportFileDisposition.externalReference);
    expect(plan.includeBytes, isFalse);
    expect(plan.referencePath, externalPath);
    expect(plan.managedSourcePath, isNull);
    expect(plan.packageRelativePath, isNull);
  });

  test(
    'managed ownership cannot turn an external path into included bytes',
    () async {
      final external = File('${sandbox.path}/external.txt');
      await external.writeAsString('external');

      await expectLater(
        planner.plan(
          storedPath: external.absolute.path,
          ownershipStorageKey: ManagedFileOwnership.vaultManagedCopy.storageKey,
          vaultDirectoryPath: vault.path,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await external.readAsString(), 'external');
    },
  );
}
