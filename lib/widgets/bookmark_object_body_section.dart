import 'package:flutter/material.dart';

import '../data/bookmark_object_detail_context.dart';
import '../data/bookmark_repository.dart';
import '../features/object/presentation/widgets/object_body_editor_section.dart';
import '../views/object_inspector_page.dart';

/// Presents the canonical universal Object Body for a legacy Bookmark host.
///
/// Bookmark -> Object identity resolution is read-only. Missing mirror rows stay
/// invisible so a presentation read never manufactures or repairs identity.
class BookmarkObjectBodySection extends StatefulWidget {
  const BookmarkObjectBodySection({
    super.key,
    required this.repository,
    required this.bookmarkId,
  });

  final BookmarkRepository repository;
  final int bookmarkId;

  @override
  State<BookmarkObjectBodySection> createState() =>
      _BookmarkObjectBodySectionState();
}

class _BookmarkObjectBodySectionState extends State<BookmarkObjectBodySection> {
  late BookmarkObjectDetailContext _objectContext;
  late Future<int?> _bookmarkObjectId;

  @override
  void initState() {
    super.initState();
    _bindRepository();
  }

  @override
  void didUpdateWidget(covariant BookmarkObjectBodySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.bookmarkId != widget.bookmarkId) {
      _bindRepository();
    }
  }

  void _bindRepository() {
    _objectContext = BookmarkObjectDetailContext.fromRepository(widget.repository);
    _bookmarkObjectId = _objectContext.objectIdForBookmark(
      workspaceId: widget.repository.workspaceId,
      bookmarkId: widget.bookmarkId,
    );
  }

  Future<void> _openObject(int objectId) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ObjectInspectorPage(
          store: _objectContext.store,
          objectStore: _objectContext.objectStore,
          objectId: objectId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<int?>(
      future: _bookmarkObjectId,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 36,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          );
        }
        final objectId = snapshot.data;
        if (objectId == null) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 18),
            ObjectBodyEditorSection(
              key: ValueKey('bookmark-object-body-${widget.bookmarkId}'),
              store: _objectContext.store,
              objectStore: _objectContext.objectStore,
              objectId: objectId,
              workspaceId: widget.repository.workspaceId,
              onOpenObject: _openObject,
            ),
          ],
        );
      },
    );
  }
}
