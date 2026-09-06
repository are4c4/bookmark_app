import 'dart:io';

import 'file_managed_resource_resolver.dart';

typedef CanonicalFilePathAction = Future<bool> Function(String filePath);

/// Open/reveal capability for one canonical File Object.
///
/// Object identity and portable path resolution remain owned by the canonical
/// File services. This capability resolves an existing managed resource first,
/// then delegates only the final OS action. It never copies, moves, deletes, or
/// rewrites the stored File identity.
class CanonicalFileActionService {
  CanonicalFileActionService({
    required FileManagedResourceResolver resources,
    CanonicalFilePathAction? openPath,
    CanonicalFilePathAction? revealPath,
  })  : _resources = resources,
        _openPath = openPath ?? _defaultOpenPath,
        _revealPath = revealPath ?? _defaultRevealPath;

  final FileManagedResourceResolver _resources;
  final CanonicalFilePathAction _openPath;
  final CanonicalFilePathAction _revealPath;

  Future<void> open({
    required int fileObjectTypeId,
    required int fileObjectId,
  }) async {
    final resource = await _requiredResource(
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
    );
    if (!await _openPath(resource.filePath)) {
      throw const CanonicalFileActionException(
        'ファイルを開けませんでした。',
      );
    }
  }

  Future<void> reveal({
    required int fileObjectTypeId,
    required int fileObjectId,
  }) async {
    final resource = await _requiredResource(
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
    );
    if (!await _revealPath(resource.filePath)) {
      throw const CanonicalFileActionException(
        'ファイルの場所を表示できませんでした。',
      );
    }
  }

  Future<FileManagedResource> _requiredResource({
    required int fileObjectTypeId,
    required int fileObjectId,
  }) async {
    final resource = await _resources.resolveManaged(
      fileObjectTypeId: fileObjectTypeId,
      fileObjectId: fileObjectId,
    );
    if (resource == null) {
      throw const CanonicalFileUnavailableException();
    }
    return resource;
  }

  static Future<bool> _defaultOpenPath(String filePath) async {
    try {
      if (Platform.isMacOS) {
        return (await Process.run('/usr/bin/open', <String>[filePath])).exitCode ==
            0;
      }
      if (Platform.isWindows) {
        return (await Process.run('explorer.exe', <String>[filePath])).exitCode ==
            0;
      }
      if (Platform.isLinux) {
        return (await Process.run('xdg-open', <String>[filePath])).exitCode == 0;
      }
    } on ProcessException {
      return false;
    }
    return false;
  }

  static Future<bool> _defaultRevealPath(String filePath) async {
    try {
      if (Platform.isMacOS) {
        return (await Process.run(
              '/usr/bin/open',
              <String>['-R', filePath],
            ))
                .exitCode ==
            0;
      }
      if (Platform.isWindows) {
        return (await Process.run(
              'explorer.exe',
              <String>['/select,$filePath'],
            ))
                .exitCode ==
            0;
      }
      if (Platform.isLinux) {
        return (await Process.run(
              'xdg-open',
              <String>[File(filePath).parent.path],
            ))
                .exitCode ==
            0;
      }
    } on ProcessException {
      return false;
    }
    return false;
  }
}

class CanonicalFileUnavailableException implements Exception {
  const CanonicalFileUnavailableException();

  @override
  String toString() => 'ファイルが見つからないか、現在利用できません。';
}

class CanonicalFileActionException implements Exception {
  const CanonicalFileActionException(this.message);

  final String message;

  @override
  String toString() => message;
}
