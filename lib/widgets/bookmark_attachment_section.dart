import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_attachment_store.dart';
import '../data/bookmark_repository.dart';
import '../services/attachment_storage_service.dart';
import '../views/attachment_viewer_page.dart';

class BookmarkAttachmentSection extends StatefulWidget {
  const BookmarkAttachmentSection({
    super.key,
    required this.repository,
    required this.bookmark,
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;

  @override
  State<BookmarkAttachmentSection> createState() => _BookmarkAttachmentSectionState();
}

class _BookmarkAttachmentSectionState extends State<BookmarkAttachmentSection> {
  late final BookmarkAttachmentStore _store;
  static const _storage = AttachmentStorageService();
  var _ready = false;
  var _importing = false;

  @override
  void initState() {
    super.initState();
    _store = BookmarkAttachmentStore(widget.repository.lifecycleStore.database);
    _initialize();
  }

  Future<void> _initialize() async {
    await _store.initialize();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  IconData _icon(BookmarkAttachment attachment) {
    if (attachment.isPdf) return Icons.picture_as_pdf_outlined;
    if (attachment.isVideo) return Icons.movie_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _import() async {
    final profilePath = widget.repository.profileDirectoryPath;
    if (profilePath == null || _importing) return;
    setState(() => _importing = true);
    try {
      final added = await _storage.importForBookmark(
        bookmarkId: widget.bookmark.id,
        profileDirectoryPath: profilePath,
        store: _store,
      );
      if (mounted && added.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${added.length}件のファイルを添付しました')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイルを添付できませんでした: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _open(BookmarkAttachment attachment) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentViewerPage(attachment: attachment),
      ),
    );
  }

  Future<void> _delete(BookmarkAttachment attachment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添付ファイルを削除しますか？'),
        content: Text('「${attachment.fileName}」をアプリの保存領域から削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) await _storage.deleteAttachment(attachment, _store);
  }

  Widget _row(BookmarkAttachment attachment) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => _open(attachment),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(_icon(attachment), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${attachment.isPdf ? 'PDF' : attachment.isVideo ? '動画' : 'ファイル'} · ${_size(attachment.sizeBytes)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '添付ファイル操作',
                iconSize: 17,
                onSelected: (value) {
                  if (value == 'open') _open(attachment);
                  if (value == 'delete') _delete(attachment);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('アプリ内で開く')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'delete', child: Text('添付を削除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 1),
      );
    }
    return StreamBuilder<List<BookmarkAttachment>>(
      stream: _store.watchForBookmark(widget.bookmark.id),
      builder: (context, snapshot) {
        final attachments = snapshot.data ?? const <BookmarkAttachment>[];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 112,
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '添付ファイル',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: attachments.isEmpty
                    ? Text(
                        'なし',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: attachments.map(_row).toList(),
                      ),
              ),
              SizedBox(
                width: 28,
                height: 28,
                child: _importing
                    ? const Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'PDF / 動画を添付',
                        onPressed: _import,
                        icon: const Icon(Icons.add, size: 17),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
