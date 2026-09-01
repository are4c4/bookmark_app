import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import 'bookmark_relation_section.dart';
import 'bookmark_reorderable_properties.dart';
import 'photo_database_picker.dart';

const _statusLabels = <String, String>{
  'unread': '未読',
  'later': '後で見る',
  'in_progress': '閲覧中 / 視聴中',
  'done': '完了 / 視聴済み',
  'archived': 'アーカイブ',
};

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
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final VoidCallback onClose;
  final ValueChanged<Tag>? onFilterByTag;
  final ValueChanged<Person>? onFilterByPerson;
  final ValueChanged<PhotoRecord>? onFilterByPhoto;
  final List<String> propertyOrder;
  final ValueChanged<List<String>>? onPropertyOrderChanged;

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

  bool _editingTitle = false;
  bool _editingUrl = false;
  bool _editingDescription = false;
  bool _savingInline = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bookmark.title);
    _urlController = TextEditingController(text: widget.bookmark.url);
    _descriptionController = TextEditingController(text: widget.bookmark.description ?? '');
    _titleFocus = FocusNode()..addListener(_handleTitleFocus);
    _urlFocus = FocusNode()..addListener(_handleUrlFocus);
    _descriptionFocus = FocusNode()..addListener(_handleDescriptionFocus);
  }

  @override
  void didUpdateWidget(covariant BookmarkDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookmark.id != widget.bookmark.id) {
      _editingTitle = false;
      _editingUrl = false;
      _editingDescription = false;
      _syncControllers(force: true);
      return;
    }
    _syncControllers();
  }

  void _syncControllers({bool force = false}) {
    if (force || !_editingTitle) _titleController.text = widget.bookmark.title;
    if (force || !_editingUrl) _urlController.text = widget.bookmark.url;
    if (force || !_editingDescription) {
      _descriptionController.text = widget.bookmark.description ?? '';
    }
  }

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

  Future<void> _saveInline({String? title, String? url, String? description}) async {
    if (_savingInline) return;
    setState(() => _savingInline = true);
    try {
      await widget.repository.update(
        id: widget.bookmark.id,
        url: url ?? widget.bookmark.url,
        title: title ?? widget.bookmark.title,
        description: description ?? widget.bookmark.description,
        thumbnail: widget.bookmark.thumbnail,
        tagNames: widget.bookmark.tags.map((tag) => tag.name),
        personNames: null,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存できませんでした: $error')),
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
    if (value.isEmpty) {
      _urlController.text = widget.bookmark.url;
      if (mounted) setState(() => _editingUrl = false);
      return;
    }
    if (mounted) setState(() => _editingUrl = false);
    if (value != widget.bookmark.url) await _saveInline(url: value);
  }

  Future<void> _saveDescription() async {
    if (!_editingDescription) return;
    final value = _descriptionController.text.trim();
    if (mounted) setState(() => _editingDescription = false);
    final current = widget.bookmark.description?.trim() ?? '';
    if (value != current) await _saveInline(description: value.isEmpty ? null : value);
  }

  void _cancelInline() {
    _titleController.text = widget.bookmark.title;
    _urlController.text = widget.bookmark.url;
    _descriptionController.text = widget.bookmark.description ?? '';
    _titleFocus.unfocus();
    _urlFocus.unfocus();
    _descriptionFocus.unfocus();
    setState(() {
      _editingTitle = false;
      _editingUrl = false;
      _editingDescription = false;
    });
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
    }
  }


  Future<void> _addPhotosFromDatabase() async {
    final allPhotos = await widget.repository.watchPhotos().first;
    if (!mounted) return;
    final result = await showPhotoDatabasePicker(
      context: context,
      photos: allPhotos,
      initiallySelectedIds: widget.bookmark.photos.map((photo) => photo.id),
      initialCoverPhotoId: widget.bookmark.coverPhoto?.id,
      title: '関連写真を選択',
    );
    if (result != null) {
      await widget.repository.attachPhotos(widget.bookmark, result.photos, coverPhoto: result.coverPhoto);
    }
  }

  Widget _cover() {
    final bookmark = widget.bookmark;
    if (bookmark.coverPhoto != null) {
      return Image.file(File(bookmark.coverPhoto!.path), width: double.infinity, height: double.infinity, fit: BoxFit.cover);
    }
    if (bookmark.thumbnail?.trim().isNotEmpty == true) {
      return Image.network(
        bookmark.thumbnail!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _coverPlaceholder(),
      );
    }
    return _coverPlaceholder();
  }

  Widget _coverPlaceholder() {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Center(
        child: Icon(Icons.image_outlined, size: 40, color: scheme.onSurfaceVariant.withValues(alpha: .55)),
      ),
    );
  }


  Widget _inlineTitle(BookmarkItem bookmark) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w700, color: scheme.onSurface);
    if (_editingTitle) {
      return Shortcuts(
        shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _CancelIntent()},
        child: Actions(
          actions: <Type, Action<Intent>>{
            _CancelIntent: CallbackAction<_CancelIntent>(onInvoke: (_) { _cancelInline(); return null; }),
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
        WidgetsBinding.instance.addPostFrameCallback((_) => _titleFocus.requestFocus());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Text(bookmark.title, style: style),
      ),
    );
  }

  Widget _inlineUrl(BookmarkItem bookmark) {
    final scheme = Theme.of(context).colorScheme;
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
      message: bookmark.url,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          setState(() => _editingUrl = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _urlFocus.requestFocus());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _compactUrl(bookmark.url),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 13, color: scheme.onSurfaceVariant.withValues(alpha: .65)),
            ],
          ),
        ),
      ),
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
        style: TextStyle(fontSize: 13, height: 1.55, color: scheme.onSurfaceVariant),
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
        WidgetsBinding.instance.addPostFrameCallback((_) => _descriptionFocus.requestFocus());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          hasDescription ? bookmark.description! : '説明を追加…',
          style: TextStyle(
            fontSize: 13,
            height: 1.55,
            color: hasDescription ? scheme.onSurfaceVariant : scheme.onSurfaceVariant.withValues(alpha: .65),
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
                  Text('詳細', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted)),
                  if (_savingInline) ...[
                    const SizedBox(width: 8),
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: bookmark.favorite ? 'お気に入り解除' : 'お気に入り',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.repository.toggleFavorite(bookmark),
                    icon: Icon(bookmark.favorite ? Icons.star : Icons.star_border, size: 19),
                  ),
                  IconButton(tooltip: '閉じる', visualDensity: VisualDensity.compact, onPressed: widget.onClose, icon: const Icon(Icons.close, size: 20)),
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
                              onPressed: () => _openUrl(bookmark.url),
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
                        Row(
                          children: [
                            Text('関連写真', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurface)),
                            const Spacer(),
                            IconButton(
                              tooltip: '写真DBから追加',
                              visualDensity: VisualDensity.compact,
                              onPressed: _addPhotosFromDatabase,
                              icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (bookmark.photos.isEmpty)
                          Text('関連写真はありません', style: TextStyle(fontSize: 12.5, color: muted))
                        else
                          SizedBox(
                            height: 104,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: bookmark.photos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final photo = bookmark.photos[index];
                                final isCover = bookmark.coverPhoto?.id == photo.id;
                                return SizedBox(
                                  width: 126,
                                  child: Material(
                                    color: scheme.surface,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(color: scheme.outlineVariant),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => widget.onFilterByPhoto?.call(photo),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Image.file(File(photo.path), fit: BoxFit.cover),
                                                if (isCover)
                                                  const Positioned(top: 5, left: 5, child: Icon(Icons.photo_size_select_actual, size: 15)),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            height: 30,
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(left: 7),
                                                    child: Text(
                                                      photo.title ?? '写真',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 11.5),
                                                    ),
                                                  ),
                                                ),
                                                PopupMenuButton<String>(
                                                  padding: EdgeInsets.zero,
                                                  iconSize: 17,
                                                  onSelected: (value) async {
                                                    if (value == 'cover') await widget.repository.setCoverPhoto(bookmark, photo);
                                                    if (value == 'clear') await widget.repository.clearCoverPhoto(bookmark);
                                                    if (value == 'detach') await widget.repository.detachPhoto(bookmark, photo);
                                                  },
                                                  itemBuilder: (_) => [
                                                    if (!isCover) const PopupMenuItem(value: 'cover', child: Text('カバーにする')),
                                                    if (isCover) const PopupMenuItem(value: 'clear', child: Text('カバー解除')),
                                                    const PopupMenuDivider(),
                                                    const PopupMenuItem(value: 'detach', child: Text('関連を解除')),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
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
                        Text('説明', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurface)),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
