import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_visual_resolver.dart';

typedef BookmarkVisualSourceResolver = Future<BookmarkVisualSource?> Function(
  BookmarkItem bookmark,
);

/// Renders one Bookmark visual through the canonical presentation resolver.
///
/// Explicit user cover photos remain first, managed Representative Images are
/// preferred over legacy remote thumbnails, and legacy remote URLs stay as the
/// compatibility fallback while older Bookmark hosts still depend on them.
class BookmarkVisualImage extends StatefulWidget {
  const BookmarkVisualImage({
    super.key,
    required this.repository,
    required this.bookmark,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.resolveSource,
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  /// Test/host seam. Production callers normally leave this null so resolution
  /// follows [BookmarkVisualResolver] and the canonical Object Relation graph.
  final BookmarkVisualSourceResolver? resolveSource;

  @override
  State<BookmarkVisualImage> createState() => _BookmarkVisualImageState();
}

class _BookmarkVisualImageState extends State<BookmarkVisualImage> {
  late Future<BookmarkVisualSource?> _source;

  @override
  void initState() {
    super.initState();
    _source = _resolve();
  }

  @override
  void didUpdateWidget(covariant BookmarkVisualImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldBookmark = oldWidget.bookmark;
    final bookmark = widget.bookmark;
    if (oldWidget.repository.workspaceId != widget.repository.workspaceId ||
        oldWidget.resolveSource != widget.resolveSource ||
        oldBookmark.id != bookmark.id ||
        oldBookmark.coverPhoto?.path != bookmark.coverPhoto?.path ||
        oldBookmark.thumbnail != bookmark.thumbnail) {
      _source = _resolve();
    }
  }

  Future<BookmarkVisualSource?> _resolve() {
    final injected = widget.resolveSource;
    if (injected != null) return injected(widget.bookmark);
    return BookmarkVisualResolver(
      database: widget.repository.workspaceStore.database,
      workspaceId: widget.repository.workspaceId,
    ).resolve(widget.bookmark);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BookmarkVisualSource?>(
      future: _source,
      builder: (context, snapshot) {
        final source = snapshot.data;
        if (source == null) return _placeholder(context);
        if (source.isLocalFile) {
          return Image.file(
            File(source.value),
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => _legacyFallback(context),
          );
        }
        return _remoteImage(source.value, context);
      },
    );
  }

  Widget _legacyFallback(BuildContext context) {
    final thumbnail = widget.bookmark.thumbnail?.trim();
    final uri = thumbnail == null ? null : Uri.tryParse(thumbnail);
    if (thumbnail == null ||
        thumbnail.isEmpty ||
        uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return _placeholder(context);
    }
    return _remoteImage(thumbnail, context);
  }

  Widget _remoteImage(String url, BuildContext context) => Image.network(
        url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );

  Widget _placeholder(BuildContext context) {
    if (widget.placeholder != null) return widget.placeholder!;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            color: scheme.onSurfaceVariant.withValues(alpha: .55),
          ),
        ),
      ),
    );
  }
}
