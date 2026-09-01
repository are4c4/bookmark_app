import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/database_view_store.dart';
import '../database/database_definition.dart';
import '../services/photo_storage_service.dart';
import '../ui/ui_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_toast.dart';
import '../widgets/bookmark_reverse_lookup_dialog.dart';
import '../widgets/database_create_tiles.dart';
import '../widgets/database_page_toolbar.dart';
import '../widgets/database_view_tabs.dart';
import '../widgets/detail_section.dart';
import '../widgets/inline_rename_text.dart';
import '../widgets/notion_inline_field.dart';
import '../widgets/resizable_detail_pane.dart';
import 'image_editor_page.dart';

enum PhotoViewType { gallery, list, table }

class PhotoManagementPage extends StatefulWidget {
  const PhotoManagementPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<PhotoManagementPage> createState() => _PhotoManagementPageState();
}

class _PhotoManagementPageState extends State<PhotoManagementPage> {
  PhotoViewType _viewType = PhotoViewType.gallery;
  int? _selectedPhotoId;
  String _query = '';
  late final DatabaseViewStore _databaseViewStore;
  DatabaseViewConfig? _activeDatabaseView;
  int? _activeDatabaseViewId;
  Timer? _viewSaveTimer;

  BookmarkRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    _databaseViewStore = DatabaseViewStore(repository.workspaceStore.database);
  }

  @override
  void dispose() {
    _viewSaveTimer?.cancel();
    super.dispose();
  }

  void _applyDatabaseView(DatabaseViewConfig view) {
    setState(() {
      _activeDatabaseView = view;
      _activeDatabaseViewId = view.id;
      _query = (view.filters['query'] as String?) ?? '';
      _viewType = switch (view.layoutType) {
        'list' => PhotoViewType.list,
        'table' => PhotoViewType.table,
        _ => PhotoViewType.gallery,
      };
    });
  }

  void _markDatabaseViewChanged() {
    final active = _activeDatabaseView;
    if (active == null) return;
    _viewSaveTimer?.cancel();
    _viewSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || _activeDatabaseViewId != active.id) return;
      final next = active.copyWith(
        layoutType: switch (_viewType) {
          PhotoViewType.list => 'list',
          PhotoViewType.table => 'table',
          _ => 'gallery',
        },
        filters: {'query': _query},
      );
      await _databaseViewStore.updateView(next);
      if (mounted && _activeDatabaseViewId == active.id) _activeDatabaseView = next;
    });
  }

  Widget _databaseViewTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 10, 0),
        child: DatabaseViewTabs(
          store: _databaseViewStore,
          definition: BuiltInDatabases.photos,
          workspaceId: repository.workspaceId,
          activeViewId: _activeDatabaseViewId,
          onSelected: _applyDatabaseView,
        ),
      );

  List<String> _split(String value) => value
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();

  List<String> _photoTagNames(PhotoRecord photo) => _split(photo.tags);

  Future<void> _renamePhoto(PhotoRecord photo, String title) =>
      repository.updatePhoto(photo, title: title, note: photo.note);

  Future<void> _saveNote(PhotoRecord photo, String value) =>
      repository.updatePhoto(
        photo,
        title: photo.title,
        note: value.trim().isEmpty ? null : value.trim(),
        tagNames: _photoTagNames(photo),
      );

  Future<void> _saveTags(PhotoRecord photo, String value) =>
      repository.updatePhoto(
        photo,
        title: photo.title,
        note: photo.note,
        tagNames: _split(value),
      );

  Future<void> _importPaths(Iterable<String> paths) async {
    try {
      final imported = await const PhotoStorageService().importPaths(paths);
      for (final photo in imported) {
        await repository.addPhoto(path: photo.path, title: photo.originalName);
      }
      if (!mounted) return;
      showAppToast(
        context,
        imported.isEmpty
            ? '対応する画像はありませんでした'
            : '${imported.length}枚の写真を追加しました',
      );
    } catch (error) {
      if (mounted) {
        showAppToast(context, '写真を追加できませんでした: $error', error: true);
      }
    }
  }

  Future<void> _import() async {
    try {
      final imported = await const PhotoStorageService().importImages();
      for (final photo in imported) {
        await repository.addPhoto(path: photo.path, title: photo.originalName);
      }
      if (!mounted) return;
      showAppToast(
        context,
        imported.isEmpty
            ? '写真は選択されませんでした'
            : '${imported.length}枚の写真を追加しました',
      );
    } catch (error) {
      if (mounted) {
        showAppToast(context, '写真を追加できませんでした: $error', error: true);
      }
    }
  }

  Future<void> _editImage(PhotoRecord photo) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ImageEditorPage(path: photo.path)),
    );
    if (changed == true) {
      await FileImage(File(photo.path)).evict();
      if (!mounted) return;
      setState(() {});
      showAppToast(context, '画像を更新しました');
    }
  }

  Future<void> _attach(PhotoRecord photo) async {
    final bookmarks = await repository.watchAll().first;
    if (!mounted || bookmarks.isEmpty) return;
    BookmarkItem? selected = bookmarks.first;
    var asCover = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('ブックマークに写真を追加'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selected?.id,
                  decoration: const InputDecoration(labelText: 'ブックマーク'),
                  items: bookmarks
                      .map(
                        (bookmark) => DropdownMenuItem(
                          value: bookmark.id,
                          child: Text(bookmark.title),
                        ),
                      )
                      .toList(),
                  onChanged: (id) => setLocalState(
                    () => selected = bookmarks
                        .where((bookmark) => bookmark.id == id)
                        .firstOrNull,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: asCover,
                  title: const Text('カバー（サムネイル）にする'),
                  onChanged: (value) => setLocalState(() => asCover = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      await repository.attachPhoto(
                        selected!,
                        photo,
                        asCover: asCover,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(PhotoRecord photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('写真を削除しますか？'),
        content: const Text('データベースから写真を削除します。ブックマークとの関連も解除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repository.deletePhoto(photo);
      if (mounted && _selectedPhotoId == photo.id) {
        setState(() => _selectedPhotoId = null);
      }
    }
  }

  void _showRelatedBookmarks(PhotoRecord photo) {
    showBookmarkReverseLookupDialog(
      context: context,
      title: 'この写真を使っているブックマーク',
      bookmarks: repository.watchBookmarksForPhoto(photo),
    );
  }

  Widget _photoName(
    PhotoRecord photo, {
    TextStyle? style,
    int maxLines = 1,
    String keyPrefix = 'photo-name',
  }) => InlineRenameText(
        key: ValueKey('$keyPrefix:${photo.id}'),
        value: photo.title ?? '',
        fallback: '写真 ${photo.id}',
        style: style,
        maxLines: maxLines,
        onSubmitted: (value) => _renamePhoto(photo, value),
      );

  Widget _card(PhotoRecord photo) {
    final tags = _photoTagNames(photo);
    final selected = _selectedPhotoId == photo.id;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(UiTokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedPhotoId = photo.id),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(UiTokens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(
                File(photo.path),
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 180,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, size: 40),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  10,
                  UiTokens.space8,
                  UiTokens.space8,
                  10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _photoName(
                      photo,
                      keyPrefix: 'photo-card-name',
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: UiTokens.textMd,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: UiTokens.space6),
                      Wrap(
                        spacing: UiTokens.space4,
                        runSpacing: UiTokens.space4,
                        children: tags
                            .take(4)
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gallery(List<PhotoRecord> photos) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1200
              ? 5
              : constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 620
                      ? 3
                      : constraints.maxWidth >= 420
                          ? 2
                          : 1;
          return MasonryGridView.count(
            padding: const EdgeInsets.fromLTRB(18, UiTokens.space16, 18, 100),
            crossAxisCount: columns,
            mainAxisSpacing: UiTokens.space12,
            crossAxisSpacing: UiTokens.space12,
            itemCount: photos.length + 1,
            itemBuilder: (_, index) {
              if (index == photos.length) {
                return DatabaseActionCard(
                  label: '写真を追加',
                  icon: Icons.add_photo_alternate_outlined,
                  onPressed: _import,
                );
              }
              return _card(photos[index]);
            },
          );
        },
      );

  Widget _list(List<PhotoRecord> photos) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, UiTokens.space12, 18, 100),
        itemCount: photos.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            return DatabaseActionRow(
              label: '写真を追加',
              icon: Icons.add_photo_alternate_outlined,
              onPressed: _import,
            );
          }
          final photo = photos[index];
          final tags = _photoTagNames(photo);
          return ListTile(
            selected: _selectedPhotoId == photo.id,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(UiTokens.radiusSm),
              child: SizedBox(
                width: 58,
                height: 44,
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            title: _photoName(
              photo,
              keyPrefix: 'photo-list-name',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Wrap(
              spacing: 5,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...tags.map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(tag, style: const TextStyle(fontSize: 11.5)),
                  ),
                ),
                if (photo.note?.trim().isNotEmpty == true)
                  Text(
                    photo.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            onTap: () => setState(() => _selectedPhotoId = photo.id),
          );
        },
      );

  Widget _table(List<PhotoRecord> photos) => Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, UiTokens.space12, 18, 8),
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('写真')),
                  DataColumn(label: Text('タグ')),
                  DataColumn(label: Text('メモ')),
                ],
                rows: photos.map((photo) {
                  final tags = _photoTagNames(photo);
                  return DataRow(
                    selected: _selectedPhotoId == photo.id,
                    onSelectChanged: (_) =>
                        setState(() => _selectedPhotoId = photo.id),
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                UiTokens.radiusSm,
                              ),
                              child: SizedBox(
                                width: 52,
                                height: 40,
                                child: Image.file(
                                  File(photo.path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: UiTokens.space8),
                            SizedBox(
                              width: 190,
                              child: _photoName(
                                photo,
                                keyPrefix: 'photo-table-name',
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(tags.join(', '))),
                      DataCell(
                        SizedBox(
                          width: 300,
                          child: Text(
                            photo.note ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          DatabaseActionRow(
            label: '写真を追加',
            icon: Icons.add_photo_alternate_outlined,
            onPressed: _import,
          ),
          const SizedBox(height: 8),
        ],
      );

  Widget _detail(PhotoRecord photo) {
    final scheme = Theme.of(context).colorScheme;
    final tags = _photoTagNames(photo);
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: UiTokens.toolbarHeight,
            child: Row(
              children: [
                const SizedBox(width: UiTokens.space16),
                const Text(
                  '写真の詳細',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '画像を編集',
                  onPressed: () => _editImage(photo),
                  icon: const Icon(Icons.crop_rotate, size: UiTokens.iconNormal),
                ),
                PopupMenuButton<String>(
                  tooltip: 'その他',
                  onSelected: (value) {
                    if (value == 'delete') _delete(photo);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('写真を削除')),
                  ],
                ),
                IconButton(
                  tooltip: '閉じる',
                  onPressed: () => setState(() => _selectedPhotoId = null),
                  icon: const Icon(Icons.close, size: 19),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                Material(
                  borderRadius: BorderRadius.circular(UiTokens.radiusMd),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _editImage(photo),
                    child: Image.file(
                      File(photo.path),
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 220,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: UiTokens.space16),
                _photoName(
                  photo,
                  keyPrefix: 'photo-detail-name',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: UiTokens.space16),
                DetailSection(
                  title: '基本情報',
                  icon: Icons.info_outline,
                  topDivider: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NotionInlineField(
                        value: photo.note ?? '',
                        hintText: 'メモを追加…',
                        maxLines: null,
                        style: const TextStyle(fontSize: 13.5, height: 1.55),
                        onSaved: (value) => _saveNote(photo, value),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '写真タグ',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      NotionInlineField(
                        value: tags.join(', '),
                        hintText: 'タグをカンマ区切りで追加…',
                        onSaved: (value) => _saveTags(photo, value),
                      ),
                    ],
                  ),
                ),
                DetailSection(
                  title: 'Relation',
                  icon: Icons.link_outlined,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bookmarks_outlined),
                        title: const Text('関連ブックマーク'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showRelatedBookmarks(photo),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.add_link),
                        title: const Text('ブックマークに追加'),
                        onTap: () => _attach(photo),
                      ),
                    ],
                  ),
                ),
                DetailSection(
                  title: '編集',
                  icon: Icons.edit_outlined,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.crop_rotate),
                    title: const Text('画像を編集'),
                    subtitle: const Text('回転・左右反転・自由トリミング'),
                    onTap: () => _editImage(photo),
                  ),
                ),
                DetailSection(
                  title: '管理',
                  icon: Icons.settings_outlined,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: scheme.error),
                    title: Text(
                      '写真を削除',
                      style: TextStyle(color: scheme.error),
                    ),
                    onTap: () => _delete(photo),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewSwitcher() => SegmentedButton<PhotoViewType>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: PhotoViewType.gallery,
            icon: Icon(Icons.grid_view, size: 17),
          ),
          ButtonSegment(
            value: PhotoViewType.list,
            icon: Icon(Icons.view_list, size: 17),
          ),
          ButtonSegment(
            value: PhotoViewType.table,
            icon: Icon(Icons.table_rows, size: 17),
          ),
        ],
        selected: {_viewType},
        onSelectionChanged: (value) => setState(() {
          _viewType = value.first;
          _markDatabaseViewChanged();
        }),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _databaseViewTabs(),
          DatabasePageToolbar(
            title: '写真',
            searchHint: '写真を検索',
            searchValue: _query,
            onSearchChanged: (value) => setState(() {
              _query = value;
              _markDatabaseViewChanged();
            }),
            viewSwitcher: _viewSwitcher(),
          ),
          Expanded(
            child: DropTarget(
              onDragDone: (details) =>
                  _importPaths(details.files.map((file) => file.path)),
              child: StreamBuilder<List<PhotoRecord>>(
                stream: repository.watchPhotos(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final q = _query.trim().toLowerCase();
                  final all = snapshot.data!;
                  final photos = q.isEmpty
                      ? all
                      : all
                          .where(
                            (photo) => [
                              photo.title ?? '',
                              photo.note ?? '',
                              photo.tags,
                            ].join(' ').toLowerCase().contains(q),
                          )
                          .toList();
                  final selected = all
                      .where((photo) => photo.id == _selectedPhotoId)
                      .firstOrNull;

                  return Row(
                    children: [
                      Expanded(
                        child: photos.isEmpty && q.isNotEmpty
                            ? const AppEmptyState(
                                icon: Icons.search_off_outlined,
                                title: '検索条件に一致する写真がありません',
                              )
                            : switch (_viewType) {
                                PhotoViewType.gallery => _gallery(photos),
                                PhotoViewType.list => _list(photos),
                                PhotoViewType.table => _table(photos),
                              },
                      ),
                      if (selected != null)
                        ResizableDetailPane(
                          storageKey: 'photo-detail-pane',
                          initialWidth: 390,
                          child: _detail(selected),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
