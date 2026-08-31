import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../data/bookmark_attachment_store.dart';

class AttachmentStorageService {
  const AttachmentStorageService();

  static const _pdfExtensions = {'pdf'};
  static const _videoExtensions = {'mp4', 'mov', 'm4v'};

  String _kindFor(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    if (_pdfExtensions.contains(ext)) return 'pdf';
    if (_videoExtensions.contains(ext)) return 'video';
    return 'file';
  }

  Future<List<BookmarkAttachment>> importForBookmark({
    required int bookmarkId,
    required String profileDirectoryPath,
    required BookmarkAttachmentStore store,
  }) async {
    const group = XTypeGroup(
      label: 'PDF / 動画',
      extensions: ['pdf', 'mp4', 'mov', 'm4v'],
    );
    final selected = await openFiles(acceptedTypeGroups: const [group]);
    if (selected.isEmpty) return const [];

    final directory = Directory('$profileDirectoryPath/attachments');
    if (!await directory.exists()) await directory.create(recursive: true);

    final result = <BookmarkAttachment>[];
    for (var i = 0; i < selected.length; i++) {
      final source = File(selected[i].path);
      if (!await source.exists()) continue;
      final originalName = selected[i].name;
      final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._\-ぁ-んァ-ヶ一-龠々ー ]'), '_');
      final targetPath = '${directory.path}/${DateTime.now().microsecondsSinceEpoch}_${i}_$safeName';
      final copied = await source.copy(targetPath);
      final stat = await copied.stat();
      final id = await store.add(
        bookmarkId: bookmarkId,
        fileName: originalName,
        path: targetPath,
        kind: _kindFor(targetPath),
        sizeBytes: stat.size,
      );
      result.add(BookmarkAttachment(
        id: id,
        bookmarkId: bookmarkId,
        fileName: originalName,
        path: targetPath,
        kind: _kindFor(targetPath),
        sizeBytes: stat.size,
        createdAt: DateTime.now(),
      ));
    }
    return result;
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
