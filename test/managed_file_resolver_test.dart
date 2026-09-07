import 'dart:io';

import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/services/managed_file_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves profile-relative stored paths and exposes safe metadata', () async {
    final root = await Directory.systemTemp.createTemp('managed_file_resolver_');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}/files/example.bin');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[1, 2, 3, 4]);

    final resolver = ManagedFileResolver(
      pathResolver: ProfilePathResolver(root.path),
    );
    final reference = await resolver.resolveExisting('files/example.bin');

    expect(reference, isNotNull);
    expect(reference?.storedPath, 'files/example.bin');
    expect(reference?.resolvedPath, file.path);
    expect(reference?.sizeBytes, 4);
    expect(reference?.modifiedAt, isA<DateTime>());
  });

  test('canonical stored path converges profile absolute and relative identity',
      () async {
    final root = await Directory.systemTemp.createTemp('managed_file_identity_');
    addTearDown(() => root.delete(recursive: true));
    final resolver = ManagedFileResolver(
      pathResolver: ProfilePathResolver(root.path),
    );

    expect(
      resolver.canonicalStoredPath('${root.path}/files/report.pdf'),
      'files/report.pdf',
    );
    expect(
      resolver.canonicalStoredPath('files/report.pdf'),
      'files/report.pdf',
    );
  });

  test('canonical stored path preserves external absolute references', () async {
    final root = await Directory.systemTemp.createTemp('managed_file_profile_');
    final external = await Directory.systemTemp.createTemp('managed_file_external_');
    addTearDown(() => root.delete(recursive: true));
    addTearDown(() => external.delete(recursive: true));
    final resolver = ManagedFileResolver(
      pathResolver: ProfilePathResolver(root.path),
    );
    final path = '${external.path}/report.pdf';

    expect(resolver.canonicalStoredPath(path), path);
  });

  test('converts managed absolute paths back to portable stored paths', () async {
    final root = await Directory.systemTemp.createTemp('managed_file_store_');
    addTearDown(() => root.delete(recursive: true));
    final resolver = ManagedFileResolver(
      pathResolver: ProfilePathResolver(root.path),
    );

    expect(
      resolver.toStoredPath('${root.path}/files/report.pdf'),
      'files/report.pdf',
    );
  });

  test('missing files fail closed and empty paths are rejected', () async {
    final resolver = const ManagedFileResolver();

    expect(await resolver.resolveExisting(''), isNull);
    expect(await resolver.resolveExisting('/definitely/missing/file.bin'), isNull);
    expect(
      () => resolver.toStoredPath('   '),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => resolver.canonicalStoredPath('   '),
      throwsA(isA<ArgumentError>()),
    );
  });
}
