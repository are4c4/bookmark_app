import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_attachment_store.dart';
import '../data/bookmark_repository.dart';
import '../services/attachment_storage_service.dart';
import '../services/pdf_metadata_service.dart';
import '../views/attachment_viewer_page.dart';
import 'detail_property_row.dart';

class BookmarkAttachmentSection extends StatefulWidget {
  const BookmarkAttachmentSection({
    super.key,
    required this.repository,
    required this.bookmark,
    this.importAttachments,
    this.readPdfMetadata,
    this.createPerson,
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final Future<List<BookmarkAttachment>> Function()? importAttachments;
  final Future<PdfFileMetadata> Function(String path)? readPdfMetadata;
  final Future<void> Function(String name)? createPerson;

  @override
  State<BookmarkAttachmentSection> createState() =>
      _BookmarkAttachmentSectionState();
}

class _BookmarkAttachmentSectionState extends State<BookmarkAttachmentSection> {
  late final BookmarkAttachmentStore _store;
  static const _storage = AttachmentStorageService();
  static const _pdfMetadata = PdfMetadataService();
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

  void _debugFailure(String operation, StackTrace stackTrace) {
    assert(() {
      debugPrint('BookmarkAttachmentSection: $operation failed.');
      debugPrintStack(stackTrace: stackTrace);
      return true;
    }());
  }

  Future<PdfFileMetadata> _readPdfMetadata(String path) {
    final reader = widget.readPdfMetadata;
    return reader == null ? _pdfMetadata.read(path) : reader(path);
  }

  Future<void> _createPerson(String name) {
    final creator = widget.createPerson;
    return creator == null ? widget.repository.createPerson(name) : creator(name);
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  IconData _icon(BookmarkAttachment attachment) => attachment.isPdf
      ? Icons.picture_as_pdf_outlined
      : attachment.isVideo
          ? Icons.movie_outlined
          : Icons.insert_drive_file_outlined;

  Future<void> _offerPdfMetadata(BookmarkAttachment attachment) async {
    final metadata = await _readPdfMetadata(attachment.path);
    if (!mounted ||
        (metadata.title.trim().isEmpty && metadata.authors.isEmpty)) {
      return;
    }
    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('PDFの情報を反映しますか？'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('タイトル: ${metadata.title}'),
              if (metadata.authors.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('著者: ${metadata.authors.join(', ')}'),
              ],
              const SizedBox(height: 12),
              const Text('タイトルを更新し、著者は人物DBの「著者」プロパティとして追加します。'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('反映しない'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('反映'),
          ),
        ],
      ),
    );
    if (apply != true) return;
    await widget.repository.update(
      id: widget.bookmark.id,
      url: widget.bookmark.url,
      title: metadata.title.trim().isEmpty
          ? widget.bookmark.title
          : metadata.title.trim(),
      thumbnail: widget.bookmark.thumbnail,
      description: widget.bookmark.description,
      tagNames: widget.bookmark.tags.map((tag) => tag.name),
      status: widget.bookmark.status,
      rating: widget.bookmark.rating,
    );
    if (metadata.authors.isNotEmpty) {
      for (final author in metadata.authors) {
        try {
          await _createPerson(author);
        } catch (_, stackTrace) {
          // Author enrichment is optional: preserve the updated bookmark while
          // exposing unexpected failures without logging the author or raw
          // exception text.
          _debugFailure('best-effort PDF author creation', stackTrace);
        }
      }
      final allPeople = await widget.repository.watchPeople().first;
      final names = metadata.authors
          .map((author) => author.trim().toLowerCase())
          .toSet();
      final authors = allPeople
          .where((person) => names.contains(person.name.trim().toLowerCase()))
          .toList();
      if (authors.isNotEmpty) {
        await widget.repository.setPeopleForRole(
          widget.bookmark,
          '著者',
          authors,
        );
      }
    }
  }

  Future<List<BookmarkAttachment>> _importAttachments() async {
    final importer = widget.importAttachments;
    if (importer != null) return importer();
    final profilePath = widget.repository.profileDirectoryPath;
    if (profilePath == null) return const [];
    return _storage.importForBookmark(
      bookmarkId: widget.bookmark.id,
      profileDirectoryPath: profilePath,
      store: _store,
    );
  }

  Future<void> _import() async {
    if (_importing) return;
    if (widget.importAttachments == null &&
        widget.repository.profileDirectoryPath == null) {
      return;
    }
    setState(() => _importing = true);
    try {
      final added = await _importAttachments();
      if (mounted && added.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${added.length}件のファイルを添付しました')),
        );
        final pdfs = added.where((attachment) => attachment.isPdf).toList();
        if (pdfs.length == 1) await _offerPdfMetadata(pdfs.first);
      }
    } catch (_, stackTrace) {
      _debugFailure('attachment import', stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ファイルを添付できませんでした。もう一度お試しください。'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _open(BookmarkAttachment attachment) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttachmentViewerPage(
          attachment: attachment,
          database: widget.repository.lifecycleStore.database,
        ),
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

  Widget _attachmentTile(BookmarkAttachment attachment) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => _open(attachment),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(
                _icon(attachment),
                size: 17,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${attachment.isPdf ? 'PDF' : attachment.isVideo ? '動画' : 'ファイル'} · ${_size(attachment.sizeBytes)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
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
                  if (value == 'metadata' && attachment.isPdf) {
                    _offerPdfMetadata(attachment);
                  }
                  if (value == 'delete') _delete(attachment);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Text('アプリ内で開く'),
                  ),
                  if (attachment.isPdf)
                    const PopupMenuItem(
                      value: 'metadata',
                      child: Text('PDFのタイトル・著者を取り込む'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Text('添付を削除')),
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
    if (!_ready) return const LinearProgressIndicator(minHeight: 1);
    return StreamBuilder<List<BookmarkAttachment>>(
      stream: _store.watchForBookmark(widget.bookmark.id),
      builder: (context, snapshot) {
        final attachments = snapshot.data ?? const <BookmarkAttachment>[];
        final scheme = Theme.of(context).colorScheme;
        return DetailPropertyRow(
          icon: Icons.attach_file,
          label: '添付ファイル',
          onAdd: _importing ? null : _import,
          addTooltip: 'PDF / 動画を添付',
          child: _importing
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                )
              : attachments.isEmpty
                  ? Text(
                      'なし',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant.withValues(alpha: .55),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: attachments.map(_attachmentTile).toList(),
                    ),
        );
      },
    );
  }
}
