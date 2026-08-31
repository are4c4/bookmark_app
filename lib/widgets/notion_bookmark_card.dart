import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';

class NotionBookmarkCard extends StatefulWidget {
  const NotionBookmarkCard({
    super.key,
    required this.bookmark,
    required this.selected,
    required this.showImage,
    required this.showUrl,
    required this.showTags,
    required this.showPeople,
    required this.showDescription,
    required this.showCreatedAt,
    required this.showFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    required this.menu,
  });

  final BookmarkItem bookmark;
  final bool selected;
  final bool showImage;
  final bool showUrl;
  final bool showTags;
  final bool showPeople;
  final bool showDescription;
  final bool showCreatedAt;
  final bool showFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final Widget menu;

  @override
  State<NotionBookmarkCard> createState() => _NotionBookmarkCardState();
}

class _NotionBookmarkCardState extends State<NotionBookmarkCard> {
  var _hovered = false;

  String _compactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
    return host;
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }

  Widget _cover() {
    final bookmark = widget.bookmark;
    if (bookmark.coverPhoto != null) {
      return Image.file(
        File(bookmark.coverPhoto!.path),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _networkCover(),
      );
    }
    return _networkCover();
  }

  Widget _networkCover() {
    final bookmark = widget.bookmark;
    if (bookmark.thumbnail?.trim().isNotEmpty == true) {
      return Image.network(
        bookmark.thumbnail!,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 150,
          child: Center(child: Icon(Icons.image_outlined, size: 36)),
        ),
      );
    }
    return const SizedBox(
      height: 150,
      child: Center(child: Icon(Icons.image_outlined, size: 36)),
    );
  }

  Widget _chip(String label, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1EF),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: const Color(0xFF6B6B68)),
              const SizedBox(width: 4),
            ],
            Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A4A47))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bookmark = widget.bookmark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.selected
                ? const Color(0xFF9B9A97)
                : _hovered
                    ? const Color(0xFFD7D7D4)
                    : const Color(0xFFE7E7E4),
          ),
          boxShadow: _hovered
              ? const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showImage)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 120, maxHeight: 240),
                    child: _cover(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              bookmark.title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF37352F),
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: _hovered ? 1 : 0,
                            duration: const Duration(milliseconds: 100),
                            child: IgnorePointer(
                              ignoring: !_hovered,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.showFavorite)
                                    SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        tooltip: 'お気に入り',
                                        onPressed: widget.onToggleFavorite,
                                        iconSize: 18,
                                        icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
                                      ),
                                    ),
                                  SizedBox(width: 30, height: 30, child: widget.menu),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.showUrl) ...[
                        const SizedBox(height: 5),
                        Text(
                          _compactUrl(bookmark.url),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF9B9A97)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (widget.showTags && bookmark.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: bookmark.tags.map((tag) => _chip(tag.name)).toList(),
                        ),
                      ],
                      if (widget.showPeople && bookmark.people.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: bookmark.people
                              .map((person) => _chip(person.name, icon: Icons.person_outline))
                              .toList(),
                        ),
                      ],
                      if (widget.showDescription && bookmark.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 9),
                        Text(
                          bookmark.description!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: Color(0xFF6B6B68),
                          ),
                        ),
                      ],
                      if (widget.showCreatedAt) ...[
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 13, color: Color(0xFFB0AFAC)),
                            const SizedBox(width: 4),
                            Text(
                              _date(bookmark.createdAt),
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFFB0AFAC)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
