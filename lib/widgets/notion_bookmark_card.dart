import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_url_resolver.dart';
import 'bookmark_visual_image.dart';

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
    required this.repository,
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
    this.onOpen,
    this.resolveUrl,
    required this.onToggleFavorite,
    required this.menu,
    this.personRoleGroups = const {},
    this.propertyOrder = const [
      'url',
      'status',
      'rating',
      'tags',
      'people',
      'favorite',
      'description',
      'createdAt',
      'history',
    ],
  });

  final BookmarkRepository repository;
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
  final VoidCallback? onOpen;
  final BookmarkUrlResolve? resolveUrl;
  final VoidCallback onToggleFavorite;
  final Widget menu;
  final Map<String, List<Person>> personRoleGroups;
  final List<String> propertyOrder;

  @override
  State<NotionBookmarkCard> createState() => _NotionBookmarkCardState();
}

class _NotionBookmarkCardState extends State<NotionBookmarkCard> {
  var _hovered = false;
  late Future<BookmarkUrlSource?> _resolvedUrl;

  Future<BookmarkUrlSource?> _resolveUrl(BookmarkItem bookmark) {
    final injected = widget.resolveUrl;
    if (injected != null) return injected(bookmark);
    return BookmarkUrlResolver(
      database: widget.repository.workspaceStore.database,
      workspaceId: widget.repository.workspaceId,
    ).resolve(bookmark);
  }

  @override
  void initState() {
    super.initState();
    _resolvedUrl = _resolveUrl(widget.bookmark);
  }

  @override
  void didUpdateWidget(covariant NotionBookmarkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.repository.workspaceId != widget.repository.workspaceId ||
        oldWidget.bookmark.id != widget.bookmark.id ||
        oldWidget.bookmark.url != widget.bookmark.url ||
        oldWidget.resolveUrl != widget.resolveUrl) {
      _resolvedUrl = _resolveUrl(widget.bookmark);
    }
  }

  Future<void> _openLink() async {
    if (widget.onOpen != null) {
      widget.onOpen!.call();
      return;
    }
    final resolved = await _resolvedUrl;
    final uri = resolved == null ? null : Uri.tryParse(resolved.value);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _compactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  }

  Widget _urlText(Color color) => FutureBuilder<BookmarkUrlSource?>(
        future: _resolvedUrl,
        builder: (context, snapshot) => Text(
          _compactUrl(snapshot.data?.value ?? widget.bookmark.url),
          style: TextStyle(fontSize: 12, color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  }

  Widget _cover() => BookmarkVisualImage(
        repository: widget.repository,
        bookmark: widget.bookmark,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        placeholder: _placeholder(),
      );

  Widget _placeholder() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 160,
      child: ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 34,
            color: scheme.onSurfaceVariant.withValues(alpha: .55),
          ),
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12.5, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ]),
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
      itemBuilder: (context) =>
          menu.itemBuilder(context).map<PopupMenuEntry<String>>((entry) {
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
                    if (mounted) menu.onSelected?.call(value);
                  });
                },
          child: entry.child,
        );
      }).toList(),
    );
  }

  List<Widget> _orderedProperties() {
    final bookmark = widget.bookmark;
    final scheme = Theme.of(context).colorScheme;
    final widgets = <Widget>[];

    void add(Widget child, {double top = 8}) {
      widgets
        ..add(SizedBox(height: top))
        ..add(child);
    }

    for (final key in widget.propertyOrder) {
      switch (key) {
        case 'image':
          break;
        case 'url':
          if (widget.showUrl) {
            add(_urlText(scheme.onSurfaceVariant), top: 5);
          }
        case 'status':
          if (widget.showStatus) {
            add(
              _chip(
                _statusLabels[bookmark.status] ?? bookmark.status,
                icon: Icons.flag_outlined,
              ),
            );
          }
        case 'rating':
          if (widget.showRating && bookmark.rating > 0) {
            add(
              Text(
                '★' * bookmark.rating,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB8860B),
                  letterSpacing: 1,
                ),
              ),
              top: 7,
            );
          }
        case 'tags':
          if (widget.showTags && bookmark.tags.isNotEmpty) {
            add(
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: bookmark.tags.map((tag) => _chip(tag.name)).toList(),
              ),
              top: 9,
            );
          }
        case 'people':
          if (widget.showPeople && bookmark.people.isNotEmpty) {
            add(
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: bookmark.people
                    .map(
                      (person) =>
                          _chip(person.name, icon: Icons.person_outline),
                    )
                    .toList(),
              ),
              top: 7,
            );
          }
        case 'favorite':
          if (widget.showFavorite && bookmark.favorite) {
            add(_chip('お気に入り', icon: Icons.star), top: 7);
          }
        case 'description':
          if (widget.showDescription &&
              bookmark.description?.trim().isNotEmpty == true) {
            add(
              Text(
                bookmark.description!,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              top: 10,
            );
          }
        case 'createdAt':
          if (widget.showCreatedAt) {
            add(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 12.5,
                    color: scheme.onSurfaceVariant.withValues(alpha: .65),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _date(bookmark.createdAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant.withValues(alpha: .75),
                    ),
                  ),
                ],
              ),
              top: 10,
            );
          }
        case 'history':
          if (widget.showHistory) {
            add(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 12.5,
                    color: scheme.onSurfaceVariant.withValues(alpha: .65),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${bookmark.openCount}回',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant.withValues(alpha: .75),
                    ),
                  ),
                ],
              ),
              top: 7,
            );
          }
        default:
          if (key.startsWith('role:')) {
            final role = key.substring(5);
            final people = widget.personRoleGroups[role] ?? const <Person>[];
            if (people.isNotEmpty) {
              add(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: people
                          .map(
                            (person) =>
                                _chip(person.name, icon: Icons.person_outline),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            }
          }
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final bookmark = widget.bookmark;
    final scheme = Theme.of(context).colorScheme;
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
                ? scheme.onSurfaceVariant
                : _hovered
                    ? scheme.outline
                    : scheme.outlineVariant,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: .08),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showImage)
                Stack(children: [
                  InkWell(onTap: _openLink, child: _cover()),
                  if (_hovered)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: .12),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: 'リンクを開く',
                              onPressed: _openLink,
                              iconSize: 17,
                              icon: const Icon(Icons.open_in_new),
                            ),
                          ),
                          if (widget.showFavorite)
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'お気に入り',
                                onPressed: widget.onToggleFavorite,
                                iconSize: 17,
                                icon: Icon(
                                  bookmark.favorite
                                      ? Icons.star
                                      : Icons.star_border,
                                ),
                              ),
                            ),
                          SizedBox(width: 30, height: 30, child: _menu()),
                        ]),
                      ),
                    ),
                ]),
              InkWell(
                onTap: widget.onTap,
                child: Padding(
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
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        tooltip: 'リンクを開く',
                                        onPressed: _openLink,
                                        iconSize: 17,
                                        icon: const Icon(Icons.open_in_new),
                                      ),
                                    ),
                                    if (widget.showFavorite)
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          tooltip: 'お気に入り',
                                          onPressed: widget.onToggleFavorite,
                                          iconSize: 17,
                                          icon: Icon(
                                            bookmark.favorite
                                                ? Icons.star
                                                : Icons.star_border,
                                          ),
                                        ),
                                      ),
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: _menu(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      ..._orderedProperties(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
