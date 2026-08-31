import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import 'person_role_properties.dart';
import 'photo_database_picker.dart';
import 'relation_database_picker.dart';

const _statusLabels = <String, String>{
  'unread': '未読',
  'later': '後で見る',
  'in_progress': '閲覧中 / 視聴中',
  'done': '完了 / 視聴済み',
  'archived': 'アーカイブ',
};

const _relationLabels = <String, String>{
  'related': '関連',
  'sequel': '続編',
  'previous': '前編',
  'reference': '参考',
  'source': '元記事 / 元動画',
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
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final VoidCallback onClose;
  final ValueChanged<Tag>? onFilterByTag;
  final ValueChanged<Person>? onFilterByPerson;
  final ValueChanged<PhotoRecord>? onFilterByPhoto;

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

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'まだ開いていません';
    final local = value.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await widget.repository.recordOpen(widget.bookmark);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
    }
  }

  Future<Tag?> _createTagFromPicker(String name, Tag? parent) async {
    final id = await widget.repository.createTag(name, parent: parent);
    final tags = await widget.repository.watchTags().first;
    for (final tag in tags) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  Future<void> _selectTagsFromDatabase() async {
    final allTags = await widget.repository.watchTags().first;
    if (!mounted) return;
    final selected = await showTagDatabasePicker(
      context: context,
      tags: allTags,
      initiallySelectedIds: widget.bookmark.tags.map((tag) => tag.id),
      onCreateTag: _createTagFromPicker,
    );
    if (selected != null) await widget.repository.setBookmarkTagsFromDatabase(widget.bookmark, selected);
  }

  Future<void> _selectCollections() async {
    final allCollections = await widget.repository.watchCollections().first;
    final selectedIds = widget.bookmark.collections.map((e) => e.id).toSet();
    if (!mounted) return;
    final result = await showDialog<List<CollectionRecord>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('コレクションを選択'),
          content: SizedBox(
            width: 430,
            height: 360,
            child: allCollections.isEmpty
                ? const Center(child: Text('コレクションがありません'))
                : ListView(
                    children: allCollections
                        .map((collection) => CheckboxListTile(
                              value: selectedIds.contains(collection.id),
                              title: Text(collection.name),
                              subtitle: collection.note?.trim().isNotEmpty == true ? Text(collection.note!) : null,
                              onChanged: (value) => setLocalState(() {
                                value == true ? selectedIds.add(collection.id) : selectedIds.remove(collection.id);
                              }),
                            ))
                        .toList(),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                allCollections.where((collection) => selectedIds.contains(collection.id)).toList(),
              ),
              child: const Text('適用'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await widget.repository.setBookmarkCollections(widget.bookmark, result);
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

  Future<void> _addBookmarkRelation() async {
    final all = (await widget.repository.watchAll().first)
        .where((item) => item.id != widget.bookmark.id)
        .toList();
    if (!mounted) return;
    BookmarkItem? selected;
    var type = 'related';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('関連ブックマークを追加'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<BookmarkItem>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'ブックマーク'),
                  items: all
                      .map((item) => DropdownMenuItem(value: item, child: Text(item.title, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) => setLocalState(() => selected = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Relation'),
                  items: _relationLabels.entries
                      .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                      .toList(),
                  onChanged: (value) => setLocalState(() => type = value ?? 'related'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      await widget.repository.addRelation(widget.bookmark, selected!, type);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
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

  Widget _coverPlaceholder() => Container(
        color: const Color(0xFFFAFAF9),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 40, color: Color(0xFFB8B7B4)),
      );

  Widget _propertyRow({
    required IconData icon,
    required String label,
    required Widget value,
    VoidCallback? onAdd,
    String? tooltip,
  }) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF9B9A97)),
                  const SizedBox(width: 7),
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF787774)))),
                ],
              ),
            ),
            Expanded(child: value),
            if (onAdd != null)
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: tooltip,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 17, color: Color(0xFF787774)),
                ),
              ),
          ],
        ),
      );

  Widget _relationChip({required String label, required VoidCallback onPressed}) => ActionChip(
        label: Text(label),
        onPressed: onPressed,
        backgroundColor: const Color(0xFFF1F1EF),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF565653)),
        visualDensity: VisualDensity.compact,
      );

  Widget _rating(BookmarkItem bookmark) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final value = index + 1;
          return InkWell(
            onTap: () => widget.repository.setRating(bookmark, bookmark.rating == value ? 0 : value),
            borderRadius: BorderRadius.circular(3),
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: Icon(
                value <= bookmark.rating ? Icons.star : Icons.star_border,
                size: 18,
                color: value <= bookmark.rating ? const Color(0xFFB8860B) : const Color(0xFF9B9A97),
              ),
            ),
          );
        }),
      );

  Widget _inlineTitle(BookmarkItem bookmark) {
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
            style: const TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w700, color: Color(0xFF37352F)),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE7E7E4))),
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
        child: Text(
          bookmark.title,
          style: const TextStyle(fontSize: 24, height: 1.2, fontWeight: FontWeight.w700, color: Color(0xFF37352F)),
        ),
      ),
    );
  }

  Widget _inlineUrl(BookmarkItem bookmark) {
    if (_editingUrl) {
      return TextField(
        controller: _urlController,
        focusNode: _urlFocus,
        autofocus: true,
        maxLines: 2,
        minLines: 1,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _saveUrl(),
        style: const TextStyle(fontSize: 13, color: Color(0xFF565653)),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE7E7E4))),
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
                  style: const TextStyle(fontSize: 13, color: Color(0xFF9B9A97)),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit_outlined, size: 13, color: Color(0xFFB0AFAC)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inlineDescription(BookmarkItem bookmark) {
    if (_editingDescription) {
      return TextField(
        controller: _descriptionController,
        focusNode: _descriptionFocus,
        autofocus: true,
        minLines: 4,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: const TextStyle(fontSize: 13, height: 1.55, color: Color(0xFF565653)),
        decoration: const InputDecoration(
          hintText: '説明を入力…',
          isDense: true,
          contentPadding: EdgeInsets.all(8),
          border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE7E7E4))),
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
            color: hasDescription ? const Color(0xFF565653) : const Color(0xFF9B9A97),
          ),
        ),
      ),
    );
  }

  Widget _relationsSection() => StreamBuilder<List<BookmarkRelation>>(
        stream: widget.repository.watchRelationsForBookmark(widget.bookmark.id),
        builder: (context, relationSnapshot) => StreamBuilder<List<BookmarkItem>>(
          stream: widget.repository.watchAll(),
          builder: (context, bookmarkSnapshot) {
            final relations = relationSnapshot.data ?? const <BookmarkRelation>[];
            final all = bookmarkSnapshot.data ?? const <BookmarkItem>[];
            if (relations.isEmpty) {
              return const Text('関連ブックマークはありません', style: TextStyle(fontSize: 12.5, color: Color(0xFF9B9A97)));
            }
            return Column(
              children: relations.map((relation) {
                final otherId = relation.sourceBookmarkId == widget.bookmark.id
                    ? relation.targetBookmarkId
                    : relation.sourceBookmarkId;
                final other = all.where((item) => item.id == otherId).firstOrNull;
                if (other == null) return const SizedBox.shrink();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link, size: 17),
                  title: Text(other.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_relationLabels[relation.relationType] ?? relation.relationType),
                  trailing: IconButton(
                    tooltip: '関連を解除',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => widget.repository.removeRelation(
                      relation.sourceBookmarkId,
                      relation.targetBookmarkId,
                      relation.relationType,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bookmark = widget.bookmark;
    return Material(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 6),
              child: Row(
                children: [
                  const Text('詳細', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF787774))),
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
          const Divider(height: 1, color: Color(0xFFE7E7E4)),
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
                        _propertyRow(
                          icon: Icons.flag_outlined,
                          label: 'ステータス',
                          value: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: bookmark.status,
                              isDense: true,
                              items: _statusLabels.entries
                                  .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value, style: const TextStyle(fontSize: 12.5))))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) widget.repository.setStatus(bookmark, value);
                              },
                            ),
                          ),
                        ),
                        _propertyRow(icon: Icons.star_outline, label: '評価', value: _rating(bookmark)),
                        _propertyRow(
                          icon: Icons.sell_outlined,
                          label: 'タグ',
                          value: bookmark.tags.isEmpty
                              ? const Text('なし', style: TextStyle(fontSize: 12.5, color: Color(0xFFB0AFAC)))
                              : Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: bookmark.tags
                                      .map((tag) => _relationChip(label: tag.name, onPressed: () => widget.onFilterByTag?.call(tag)))
                                      .toList(),
                                ),
                          onAdd: _selectTagsFromDatabase,
                          tooltip: 'タグDBから選択・新規作成',
                        ),
                        PersonRoleProperties(
                          repository: widget.repository,
                          bookmark: bookmark,
                          onFilterByPerson: widget.onFilterByPerson,
                        ),
                        _propertyRow(
                          icon: Icons.collections_bookmark_outlined,
                          label: 'コレクション',
                          value: bookmark.collections.isEmpty
                              ? const Text('なし', style: TextStyle(fontSize: 12.5, color: Color(0xFFB0AFAC)))
                              : Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: bookmark.collections
                                      .map((collection) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                            decoration: BoxDecoration(color: const Color(0xFFF1F1EF), borderRadius: BorderRadius.circular(4)),
                                            child: Text(collection.name, style: const TextStyle(fontSize: 12)),
                                          ))
                                      .toList(),
                                ),
                          onAdd: _selectCollections,
                          tooltip: 'コレクションを選択',
                        ),
                        _propertyRow(
                          icon: Icons.history,
                          label: '履歴',
                          value: Text(
                            '${bookmark.openCount}回 · ${_formatDateTime(bookmark.lastOpenedAt)}',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF787774)),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1, color: Color(0xFFEDEDEB)),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Text('関連写真', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37352F))),
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
                          const Text('関連写真はありません', style: TextStyle(fontSize: 12.5, color: Color(0xFF9B9A97)))
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
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      side: const BorderSide(color: Color(0xFFE7E7E4)),
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
                        const Divider(height: 1, color: Color(0xFFEDEDEB)),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Text('関連ブックマーク', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37352F))),
                            const Spacer(),
                            IconButton(tooltip: '関連を追加', onPressed: _addBookmarkRelation, icon: const Icon(Icons.add_link, size: 19)),
                          ],
                        ),
                        _relationsSection(),
                        const SizedBox(height: 22),
                        const Divider(height: 1, color: Color(0xFFEDEDEB)),
                        const SizedBox(height: 18),
                        const Text('説明', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37352F))),
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
