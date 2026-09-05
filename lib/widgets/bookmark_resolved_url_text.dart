import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../services/bookmark_url_resolver.dart';

/// Displays the preferred canonical Bookmark -> Weblink URL while preserving
/// the legacy Bookmark URL as a presentation-only compatibility fallback.
class BookmarkResolvedUrlText extends StatefulWidget {
  const BookmarkResolvedUrlText({
    super.key,
    required this.bookmark,
    required this.resolveUrl,
    this.compact = false,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final BookmarkItem bookmark;
  final BookmarkUrlResolve resolveUrl;
  final bool compact;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  State<BookmarkResolvedUrlText> createState() =>
      _BookmarkResolvedUrlTextState();
}

class _BookmarkResolvedUrlTextState extends State<BookmarkResolvedUrlText> {
  late Future<BookmarkUrlSource?> _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = widget.resolveUrl(widget.bookmark);
  }

  @override
  void didUpdateWidget(covariant BookmarkResolvedUrlText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookmark.id != widget.bookmark.id ||
        oldWidget.bookmark.url != widget.bookmark.url ||
        oldWidget.resolveUrl != widget.resolveUrl) {
      _resolved = widget.resolveUrl(widget.bookmark);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BookmarkUrlSource?>(
        future: _resolved,
        builder: (context, snapshot) {
          final value = snapshot.data?.value ?? widget.bookmark.url;
          return Text(
            widget.compact ? _compactUrl(value) : value,
            style: widget.style,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
          );
        },
      );

  String _compactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  }
}
