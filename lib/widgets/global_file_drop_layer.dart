import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../data/bookmark_attachment_store.dart';
import '../data/bookmark_repository.dart';
import '../services/attachment_storage_service.dart';
import '../services/pdf_metadata_service.dart';

class GlobalFileDropLayer extends StatefulWidget {
  const GlobalFileDropLayer({
    super.key,
    required this.repository,
    required this.child,
  });

  final BookmarkRepository repository;
  final Widget child;

  @override
  State<GlobalFileDropLayer> createState() => _GlobalFileDropLayerState();
}

class _GlobalFileDropLayerState extends State<GlobalFileDropLayer> {
  bool _draggingSupportedFile = false;
  bool _importing = false;

  bool _supported(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  String _fileTitle(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.substring(normalized.lastIndexOf('/') + 1);
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  void _debugFailure(String operation, StackTrace stackTrace) {
    assert(() {
      debugPrint('GlobalFileDropLayer: $operation failed.');
      debugPrintStack(stackTrace: stackTrace);
      return true;
    }());
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (_importing) return;
    final paths = details.files.map((file) => file.path).where(_supported).toList();
    setState(() => _draggingSupportedFile = false);
    if (paths.isEmpty) return;
    final profilePath = widget.repository.profileDirectoryPath;
    if (profilePath == null) return;

    setState(() => _importing = true);
    final store = BookmarkAttachmentStore(widget.repository.lifecycleStore.database);
    try {
      await store.initialize();
      const storage = AttachmentStorageService();
      var createdCount = 0;
      for (final path in paths) {
        final isPdf = path.toLowerCase().endsWith('.pdf');
        final metadata = isPdf
            ? await const PdfMetadataService().read(path)
            : PdfFileMetadata(title: _fileTitle(path));
        final id = await widget.repository.create(
          url: 'local-file://${DateTime.now().microsecondsSinceEpoch}/$createdCount',
          title: metadata.title,
          inbox: true,
        );
        final attachments = await storage.importPathsForBookmark(
          bookmarkId: id,
          profileDirectoryPath: profilePath,
          store: store,
          sourcePaths: [path],
        );
        if (attachments.isEmpty) continue;
        await widget.repository.update(
          id: id,
          url: Uri.file(attachments.first.path).toString(),
          title: metadata.title,
        );

        if (isPdf && metadata.authors.isNotEmpty) {
          for (final author in metadata.authors) {
            try {
              await widget.repository.createPerson(author);
            } catch (_, stackTrace) {
              // Author enrichment is best-effort: the imported file/bookmark is
              // already valid, so keep the import successful but expose
              // unexpected failures during development without logging
              // user-provided names or exception text.
              _debugFailure('best-effort PDF author creation', stackTrace);
            }
          }
          final allPeople = await widget.repository.watchPeople().first;
          final names = metadata.authors.map((e) => e.trim().toLowerCase()).toSet();
          final authors = allPeople
              .where((person) => names.contains(person.name.trim().toLowerCase()))
              .toList();
          final bookmarks = await widget.repository.watchAll().first;
          final matches = bookmarks.where((bookmark) => bookmark.id == id);
          if (matches.isNotEmpty && authors.isNotEmpty) {
            await widget.repository.setPeopleForRole(matches.first, '著者', authors);
          }
        }
        createdCount++;
      }
      if (mounted && createdCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$createdCount件をInboxへ追加しました')),
        );
      }
    } catch (_, stackTrace) {
      _debugFailure('file drop import', stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF / 動画を取り込めませんでした。もう一度お試しください。'),
          ),
        );
      }
    } finally {
      await store.dispose();
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) {
        if (!_draggingSupportedFile) setState(() => _draggingSupportedFile = true);
      },
      onDragExited: (_) {
        if (_draggingSupportedFile) setState(() => _draggingSupportedFile = false);
      },
      onDragDone: _handleDrop,
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (_draggingSupportedFile || _importing)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: .82),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_importing) ...[
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 12),
                            ] else ...[
                              const Icon(Icons.file_download_outlined),
                              const SizedBox(width: 10),
                            ],
                            Text(_importing ? 'PDF / 動画を取り込み中…' : 'PDF / 動画をドロップしてInboxへ追加'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
