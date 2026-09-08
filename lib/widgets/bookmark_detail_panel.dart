import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../services/bookmark_presentation_resolver_factory.dart';
import '../services/bookmark_url_resolver.dart';
import 'bookmark_image_relation_section.dart';
import 'bookmark_relation_section.dart';
import 'bookmark_reorderable_properties.dart';
import 'bookmark_visual_image.dart';

class BookmarkDetailPanel extends StatefulWidget {
  const BookmarkDetailPanel({
    super.key,
    required this.repository,
    required this.bookmark,
    required this.onClose,
    this.onFilterByTag,
    this.onFilterByPerson,
    this.onFilterByPhoto,
    this.propertyOrder = const [],
    this.onPropertyOrderChanged,
    this.resolveUrl,
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final VoidCallback onClose;
  final ValueChanged<Tag>? onFilterByTag;
  final ValueChanged<Person>? onFilterByPerson;
  final ValueChanged<PhotoRecord>? onFilterByPhoto;
  final List<String> propertyOrder;
  final ValueChanged<List<String>>? onPropertyOrderChanged;
  final BookmarkUrlResolve? resolveUrl;

  @override
  State<BookmarkDetailPanel> createState() => _BookmarkDetailPanelState();
}

class _BookmarkDetailPanelState extends State<BookmarkDetailPanel> {
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _descriptionController;
  late final FocusNode _titleFocus;
  late final FocusNode _urlFocus;
  late final FocusNode _descriptionFocus;
  late BookmarkUrlResolve _resolveBookmarkUrl;
  late Future<BookmarkUrlSource?> _resolvedUrl;

  bool _editingTitle = false;
  bool _editingUrl = false;
  bool _editingDescription = false;
  bool _savingInline = false;
  String? _editingUrlBaseline;
  int _imageVisualRevision = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bookmark.title);
    _urlController = TextEditingController(text: widget.bookmark.url);
    _descriptionController =
        TextEditingController(text: widget.bookmark.description ?? '');
    _titleFocus = FocusNode()..addListener(_handleTitleFocus);
    _urlFocus = FocusNode()..addListener(_handleUrlFocus);
    _descriptionFocus = FocusNode()..addListener(_handleDescriptionFocus);
    _configureUrlResolver();
  }

  @override
  void didUpdateWidget(covariant BookmarkDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final urlContextChanged =
        oldWidget.repository != widget.repository ||
        oldWidget.repository.workspaceId != widget.repository.workspaceId ||
        oldWidget.bookmark.id != widget.bookmark.id ||
        oldWidget.bookmark.url != widget.bookmark.url ||
        oldWidget.resolveUrl != widget.resolveUrl;
    if (urlContextChanged) {
      _configureUrlResolver();
    }
    if (oldWidget.bookmark.id != widget.bookmark.id) {
      _editingTitle = false;
      _editingUrl = false;
      _editingDescription = false;
      _editingUrlBaseline = null;
      _imageVisualRevision = 0;
      _syncControllers(force: true);
      return;
    }
    _syncControllers();
  }

  void _configureUrlResolver() {
    _resolveBookmarkUrl = widget.resolveUrl ??
        BookmarkPresentationResolverFactory.urlFor(widget.repository);
    _resolvedUrl = _resolveBookmarkUrl(widget.bookmark);
    _syncUrlControllerFromResolved();
  }

  void _syncControllers({bool force = false}) {
    if (force || !_editingTitle) _titleController.text = widget.bookmark.title;
    if (force || !_editingUrl) _syncUrlControllerFromResolved();
    if (force || !_editingDescription) {
      _descriptionController.text = widget.bookmark.description ?? '';
    }
  }

  void _syncUrlControllerFromResolved() {
    final future = _resolvedUrl;
    final bookmarkId = widget.bookmark.id;
    future.then((resolved) {
      if (!mounted ||
          !identical(future, _resolvedUrl) ||
          widget.bookmark.id != bookmarkId ||
          _editingUrl) {
        return;
      }
      _urlController.text = resolved?.value ?? widget.bookmark.url;
    });
  }

  Future<String> _preferredUrl() async =>
      (await _resolvedUrl)?.value ?? widget.bookmark.url;

  void _handleTitleFocus() {
    if (!_titleFocus.hasFocus && _editingTitle) _saveTitle();
  }

  void _handleUrlFocus() {
    if (!_urlFocus.hasFocus && _editingUrl) _saveUrl();
  }

  void _handleDescriptionFocus() {
    if (!_descriptionFocus.hasFocus && _editingDescription) _saveDescription();
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_handleTitleFocus);
    _urlFocus.removeListener(_handleUrlFocus);
    _descriptionFocus.removeListener(_handleDescriptionFocus);
    _titleController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    _titleFocus.dispose();
    _urlFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  Future<void> _saveInline({
    String? title,
    String? url,
    String? description,
  }) async {
    if (_savingInline) return;
    setState(() => _savingInline = true);
    try {
      final effectiveUrl = url ?? await _preferredUrl();
      await widget.repository.update(
        id: widget.bookmark.id,
        url: effectiveUrl,
        title: title ?? widget.bookmark.title,
        description: description ?? widget.bookmark.description,
        thumbnail: widget.bookmark.thumbnail,
        tagNames: widget.bookmark.tags.map((tag) => tag.name),
        personNames: null,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存できませんでした。')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingInline = false);
    }
  }

  Future<void> _saveTitle() async {
    if (!_editingTitle) return;
    final value = _titleController.text.trim();
    if (value.isEmpty) {
      _titleController.text = widget.bookmark.title;
      if (mounted) setState(() => _editingTitle = false);
      return;
    }
    if (mounted) setState(() => _editingTitle = false);
    if (value != widget.bookmark.title) await _saveInline(title: value);
  }

  Future<void> _saveUrl() async {
    if (!_editingUrl) return;
    final value = _urlController.text.trim();
    final current = _editingUrlBaseline ?? widget.bookmark.url;
    _editingUrlBaseline = null;
    if (value.isEmpty) {
      if (mounted) setState(() => _editingUrl = false);
      _syncUrlControllerFromResolved();
      return;
    }
    if (mounted) setState(() => _editingUrl = false);
    if (value != current) await _saveInline(url: value);
  }

  Future<void> _saveDescription() async {
    if (!_editingDescription) return;
    final value = _descriptionController.text.trim();
    if (mounted) setState(() => _editingDescription = false);
    final current = widget.bookmark.description?.trim() ?? '';
    if (value != current) {
      await _saveInline(description: value.isEmpty ? null : value);
    }
  }

  void _cancelInline() {
    _titleController.text = widget.bookmark.title;
    _editingUrlBaseline = null;
    _descriptionController.text = widget.bookmark.description ?? '';
    _titleFocus.unfocus();
    _urlFocus.unfocus();
    _descriptionFocus.unfocus();
    setState(() {
      _editingTitle = false;
      _editingUrl = false;
      _editingDescription = false;
    });
    _syncUrlControllerFromResolved();
  }

  String _compactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return value;
    return uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await widget.repository.recordOpen(widget.bookmark);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URLを開けませんでした')),
      );
    }
  }

  Future<void> _openResolvedUrl() async {
    try {
      final resolved = await _resolvedUrl;
      if (resolved == null) return;
      await _openUrl(resolved.value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URLを開けませんでした')),
        );
      }
    }
  }

  Widget _cover() => BookmarkVisualImage(
        key: ValueKey(
          'bookmark-detail-cover-${widget.bookmark.id}-$_imageVisualRevision',
        ),
        repository: widget.repository,
        bookmark: widget.bookmark,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: _coverPlaceholder(),
      );

  Widget _coverPlaceholder() {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: scheme.onSurfaceVariant.withValues(alpha: .55),
        ),
      ),
    );
  }

  Widget _inlineTitle(BookmarkItem bookmark) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );
    if (_editingTitle) {
      return Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _CancelIntent: CallbackAction<_CancelIntent>(
              onInvoke: (_) {
                _cancelInline();
                return null;
              },
            ),
          },
          child: TextField(
            controller: _titleController,
            focusNode: _titleFocus,
            autofocus: true,
            maxLines: null,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveTitle(),
            style: style,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            ),
          ),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        setState(() => _editingTitle = true);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _titleFocus.requestFocus(),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Text(bookmark.title, style: style),
      ),
    );
  }

  Widget _inlineUrl(BookmarkItem bookmark) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<BookmarkUrlSource?>(
      future: _resolvedUrl,
      builder: (context, snapshot) {
        final value = snapshot.data?.value ?? bookmark.url;
        if (_editingUrl) {
          return TextField(
            controller: _urlController,
            focusNode: _urlFocus,
            autofocus: true,
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveUrl(),
            style: TextStyle(fontSize: 13, color: scheme.onSurface),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
          );
        }
        return Tooltip(
          message: value,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () {
              _urlController.text = value;
              _editingUrlBaseline = value;
              setState(() => _editingUrl = true);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _urlFocus.requestFocus(),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _compactUrl(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_outlined,
                    size: 13,
                    color: scheme.onSurfaceVariant.withValues(alpha: .65),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _inlineDescription(BookmarkItem bookmark) {
    final scheme = Theme.of(context).colorScheme;
    if (_editingDescription) {
      return TextField(
        controller: _descriptionController,
        focusNode: _descriptionFocus,
        autofocus: true,
        minLines: 4,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontSize: 13,
          height: 1.55,
          color: scheme.onSurfaceVariant,
        ),
        decoration: const InputDecoration(
          hintText: '説明を入力…',
          isDense: true,
          contentPadding: EdgeInsets.all(8),
        ),
      );
    }
    final hasDescription = bookmark.description?.trim().isNotEmpty == true;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        setState(() => _editingDescription = true);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _descriptionFocus.requestFocus(),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          hasDescription ? bookmark.description! : '説明を追加…',
          style: TextStyle(
            fontSize: 13,
            height: 1.55,
            color: hasDescription
                ? scheme.onSurfaceVariant
                : scheme.onSurfaceVariant.withValues(alpha: .65),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookmark = widget.bookmark;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 6),
              child: Row(
                children: [
                  Text(
                    '詳細',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  if (_savingInline) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: bookmark.favorite ? 'お気に入り解除' : 'お気に入り',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.repository.toggleFavorite(bookmark),
                    icon: Icon(
                      bookmark.favorite ? Icons.star : Icons.star_border,
                      size: 19,
                    ),
                  ),
                  IconButton(
                    tooltip: '閉じる',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: _cover()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _inlineTitle(bookmark),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _inlineUrl(bookmark)),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              onPressed: _openResolvedUrl,
                              icon: const Icon(Icons.open_in_new, size: 15),
                              label: const Text('開く'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        BookmarkReorderableProperties(
                          repository: widget.repository,
                          bookmark: bookmark,
                          propertyOrder: widget.propertyOrder,
                          onPropertyOrderChanged: (order) =>
                              widget.onPropertyOrderChanged?.call(order),
                          onFilterByTag: widget.onFilterByTag,
                          onFilterByPerson: widget.onFilterByPerson,
                        ),
                        const SizedBox(height: 18),
                        Divider(height: 1, color: scheme.outlineVariant),
                        const SizedBox(height: 18),
                        BookmarkImageRelationSection(
                          repository: widget.repository,
                          bookmark: bookmark,
                          onFilterByLegacyPhoto: widget.onFilterByPhoto,
                          onChanged: () {
                            if (!mounted) return;
                            setState(() => _imageVisualRevision += 1);
                          },
                        ),
                        const SizedBox(height: 22),
                        Divider(height: 1, color: scheme.outlineVariant),
                        const SizedBox(height: 18),
                        BookmarkRelationSection(
                          repository: widget.repository,
                          bookmark: bookmark,
                        ),
                        const SizedBox(height: 22),
                        Divider(height: 1, color: scheme.outlineVariant),
                        const SizedBox(height: 18),
                        Text(
                          '説明',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _inlineDescription(bookmark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelIntent extends Intent {
  const _CancelIntent();
}
