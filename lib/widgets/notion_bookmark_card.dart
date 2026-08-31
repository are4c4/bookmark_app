import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';

const _statusLabels = <String, String>{
  'unread': '未読',
  'later': '後で見る',
  'in_progress': '閲覧中',
  'done': '完了',
  'archived': 'アーカイブ',
};

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
    required this.showStatus,
    required this.showRating,
    required this.showHistory,
    required this.onTap,
    required this.onToggleFavorite,
    required this.menu,
    this.personRoleGroups = const {},
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
  final bool showStatus;
  final bool showRating;
  final bool showHistory;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final Widget menu;
  final Map<String, List<Person>> personRoleGroups;

  @override
  State<NotionBookmarkCard> createState() => _NotionBookmarkCardState();
}

class _NotionBookmarkCardState extends State<NotionBookmarkCard> {
  var _hovered = false;

  String _compactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
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
        fit: BoxFit.fitWidth,
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
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 160,
      child: ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Center(
          child: Icon(Icons.image_outlined, size: 34, color: scheme.onSurfaceVariant.withValues(alpha: .55)),
        ),
      ),
    );
  }

  Widget _chip(String label, {IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.5, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 12, height: 1.2, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _menu() {
    final menu = widget.menu;
    if (menu is! PopupMenuButton<String>) return menu;

    return PopupMenuButton<String>(
      tooltip: menu.tooltip,
      icon: menu.icon,
      iconSize: menu.iconSize,
      initialValue: menu.initialValue,
      enabled: menu.enabled,
      onCanceled: menu.onCanceled,
      itemBuilder: (context) {
        final originalItems = menu.itemBuilder(context);
        return originalItems.map<PopupMenuEntry<String>>((entry) {
          if (entry is! PopupMenuItem<String>) return entry;
          final value = entry.value;
          return PopupMenuItem<String>(
            value: value,
            enabled: entry.enabled,
            height: entry.height,
            padding: entry.padding,
            onTap: value == null
                ? entry.onTap
                : () {
                    entry.onTap?.call();
                    Future<void>.delayed(const Duration(milliseconds: 120), () {
                      if (!mounted) return;
                      menu.onSelected?.call(value);
                    });
                  },
            child: entry.child,
          );
        }).toList();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookmark = widget.bookmark;
    final scheme = Theme.of(context).colorScheme;
    final selectedBorder = scheme.onSurfaceVariant;
    final hoverBorder = scheme.outline;
    final normalBorder = scheme.outlineVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: widget.selected
                ? selectedBorder
                : _hovered
                    ? hoverBorder
                    : normalBorder,
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: scheme.shadow.withValues(alpha: .08), blurRadius: 7, offset: const Offset(0, 2))]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showImage)
                  Stack(
                    children: [
                      _cover(),
                      if (_hovered)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: .94),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: .12), blurRadius: 4)],
                            ),
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
                                      iconSize: 17,
                                      icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
                                    ),
                                  ),
                                SizedBox(width: 30, height: 30, child: _menu()),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
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
                              style: TextStyle(
                                fontSize: 14.5,
                                height: 1.28,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (!widget.showImage)
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
                                        width: 28,
                                        height: 28,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          tooltip: 'お気に入り',
                                          onPressed: widget.onToggleFavorite,
                                          iconSize: 17,
                                          icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border),
                                        ),
                                      ),
                                    SizedBox(width: 28, height: 28, child: _menu()),
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
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (widget.showStatus) ...[
                        const SizedBox(height: 8),
                        _chip(_statusLabels[bookmark.status] ?? bookmark.status, icon: Icons.flag_outlined),
                      ],
                      if (widget.showRating && bookmark.rating > 0) ...[
                        const SizedBox(height: 7),
                        Text('★' * bookmark.rating, style: const TextStyle(fontSize: 13, color: Color(0xFFB8860B), letterSpacing: 1)),
                      ],
                      if (widget.showTags && bookmark.tags.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Wrap(spacing: 5, runSpacing: 5, children: bookmark.tags.map((tag) => _chip(tag.name)).toList()),
                      ],
                      if (widget.showPeople && bookmark.people.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(spacing: 5, runSpacing: 5, children: bookmark.people.map((person) => _chip(person.name, icon: Icons.person_outline)).toList()),
                      ],
                      ...widget.personRoleGroups.entries.expand((entry) sync* {
                        if (entry.value.isEmpty) return;
                        yield const SizedBox(height: 8);
                        yield Text(entry.key, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant));
                        yield const SizedBox(height: 4);
                        yield Wrap(
                          spacing: 5,
                          runSpacing: 5,
                          children: entry.value.map((person) => _chip(person.name, icon: Icons.person_outline)).toList(),
                        );
                      }),
                      if (widget.showDescription && bookmark.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        Text(bookmark.description!, style: TextStyle(fontSize: 12.5, height: 1.5, color: scheme.onSurfaceVariant)),
                      ],
                      if (widget.showCreatedAt || widget.showHistory) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            if (widget.showCreatedAt)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.schedule, size: 12.5, color: scheme.onSurfaceVariant.withValues(alpha: .65)),
                                const SizedBox(width: 4),
                                Text(_date(bookmark.createdAt), style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant.withValues(alpha: .75))),
                              ]),
                            if (widget.showHistory)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.history, size: 12.5, color: scheme.onSurfaceVariant.withValues(alpha: .65)),
                                const SizedBox(width: 4),
                                Text('${bookmark.openCount}回', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant.withValues(alpha: .75))),
                              ]),
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
