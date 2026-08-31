import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../data/bookmark_attachment_store.dart';

class AttachmentStorageService {
  const AttachmentStorageService();

  static const _pdfExtensions = {'pdf'};
  static const _videoExtensions = {'mp4', 'mov', 'm4v'};
  static const _allowedExtensions = {'pdf', 'mp4', 'mov', 'm4v'};

  String _kindFor(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    if (_pdfExtensions.contains(ext)) return 'pdf';
    if (_videoExtensions.contains(ext)) return 'video';
    return 'file';
  }

  Future<List<String>> pickFiles() =>
      Platform.isMacOS ? _pickAttachmentsOnMacOS() : _pickAttachmentsWithFileSelector();

  Future<List<BookmarkAttachment>> importForBookmark({
    required int bookmarkId,
    required String profileDirectoryPath,
    required BookmarkAttachmentStore store,
  }) async {
    final sourcePaths = await pickFiles();
    return importPathsForBookmark(
      bookmarkId: bookmarkId,
      profileDirectoryPath: profileDirectoryPath,
      store: store,
      sourcePaths: sourcePaths,
    );
  }

  Future<List<BookmarkAttachment>> importPathsForBookmark({
    required int bookmarkId,
    required String profileDirectoryPath,
    required BookmarkAttachmentStore store,
    required Iterable<String> sourcePaths,
  }) async {
    final paths = sourcePaths.where(_isSupported).toList();
    if (paths.isEmpty) return const [];

    final directory = Directory('$profileDirectoryPath/attachments');
    if (!await directory.exists()) await directory.create(recursive: true);

    final result = <BookmarkAttachment>[];
    for (var i = 0; i < paths.length; i++) {
      final sourcePath = paths[i];
      final source = File(sourcePath);
      if (!await source.exists()) continue;
      final originalName = _fileName(source.path);
      final safeName = originalName.replaceAll(
        RegExp(r'[^A-Za-z0-9._\-ぁ-んァ-ヶ一-龠々ー ]'),
        '_',
      );
      final targetPath =
          '${directory.path}/${DateTime.now().microsecondsSinceEpoch}_${i}_$safeName';
      final copied = await source.copy(targetPath);
      final stat = await copied.stat();
      final kind = _kindFor(targetPath);
      final id = await store.add(
        bookmarkId: bookmarkId,
        fileName: originalName,
        path: targetPath,
        kind: kind,
        sizeBytes: stat.size,
      );
      result.add(
        BookmarkAttachment(
          id: id,
          bookmarkId: bookmarkId,
          fileName: originalName,
          path: targetPath,
          kind: kind,
          sizeBytes: stat.size,
          createdAt: DateTime.now(),
        ),
      );
    }
    return result;
  }

  Future<List<String>> _pickAttachmentsWithFileSelector() async {
    const group = XTypeGroup(
      label: 'PDF / 動画',
      extensions: ['pdf', 'mp4', 'mov', 'm4v'],
    );
    final selected = await openFiles(acceptedTypeGroups: const [group]);
    return selected.map((file) => file.path).where(_isSupported).toList();
  }

  Future<List<String>> _pickAttachmentsOnMacOS() async {
    const script = r'''
set selectedFiles to choose file with prompt "PDF / 動画を選択" with multiple selections allowed
set output to ""
repeat with selectedFile in selectedFiles
  set output to output & POSIX path of selectedFile & linefeed
end repeat
return output
''';

    final result = await Process.run(
      '/usr/bin/osascript',
      const ['-e', script],
      runInShell: false,
    );

    if (result.exitCode != 0) {
      final error = result.stderr.toString().trim();
      if (error.contains('User canceled') || error.contains('(-128)')) {
        return const [];
      }
      throw StateError(
        error.isEmpty
            ? 'macOSのファイル選択画面を開けませんでした (exit ${result.exitCode})'
            : error,
      );
    }

    return result.stdout
        .toString()
        .split('\n')
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .where(_isSupported)
        .toList();
  }

  bool _isSupported(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return false;
    return _allowedExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }

  Future<void> deleteAttachment(
    BookmarkAttachment attachment,
    BookmarkAttachmentStore store,
  ) async {
    final file = File(attachment.path);
    if (await file.exists()) await file.delete();
    await store.remove(attachment.id);
  }
}
