import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../ui/ui_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/bookmark_reverse_lookup_dialog.dart';
import '../widgets/database_page_toolbar.dart';
import '../widgets/detail_section.dart';
import '../widgets/photo_database_picker.dart';

enum PeopleViewType { gallery, list, table }

class PeopleManagementPage extends StatefulWidget {
  const PeopleManagementPage({super.key, required this.repository});
  final BookmarkRepository repository;

  @override
  State<PeopleManagementPage> createState() => _PeopleManagementPageState();
}

class _PeopleManagementPageState extends State<PeopleManagementPage> {
  PeopleViewType _viewType = PeopleViewType.gallery;
  String _query = '';
  int? _selectedPersonId;

  BookmarkRepository get repository => widget.repository;

  PhotoRecord? _profilePhoto(Person person, List<PhotoRecord> photos) =>
      photos.where((photo) => photo.id == person.profilePhotoId).firstOrNull;

  List<BookmarkItem> _bookmarksFor(Person person, List<BookmarkItem> bookmarks) =>
      bookmarks.where((bookmark) => bookmark.people.any((candidate) => candidate.id == person.id)).toList();

  Future<void> _create() async {
    var name = '';
    var note = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('人物を追加'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(autofocus: true, decoration: const InputDecoration(labelText: '名前'), onChanged: (v) => name = v),
            const SizedBox(height: UiTokens.space12),
            TextFormField(maxLines: 3, decoration: const InputDecoration(labelText: 'メモ'), onChanged: (v) => note = v),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('追加')),
        ],
      ),
    );
    if (ok == true && name.trim().isNotEmpty) await repository.createPerson(name.trim(), note: note.trim());
  }

  Future<void> _edit(Person person, List<PhotoRecord> photos) async {
    var name = person.name;
    var note = person.note ?? '';
    PhotoRecord? profilePhoto = _profilePhoto(person, photos);
    var updateProfilePhoto = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('人物プロフィールを編集'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                TextFormField(initialValue: name, decoration: const InputDecoration(labelText: '名前'), onChanged: (v) => name = v),
                const SizedBox(height: UiTokens.space12),
                TextFormField(initialValue: note, maxLines: 4, decoration: const InputDecoration(labelText: 'メモ'), onChanged: (v) => note = v),
                const SizedBox(height: UiTokens.space16),
                const Text('プロフィール画像', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: UiTokens.space8),
                if (profilePhoto != null)
                  ClipRRect(borderRadius: BorderRadius.circular(UiTokens.radiusMd), child: SizedBox(width: 190, child: Image.file(File(profilePhoto!.path), fit: BoxFit.fitWidth)))
                else
                  Container(width: 190, height: 150, alignment: Alignment.center, color: Theme.of(context).colorScheme.surfaceContainerLow, child: const Icon(Icons.person_outline, size: 52)),
                const SizedBox(height: UiTokens.space8),
                Wrap(spacing: UiTokens.space8, children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await showPhotoDatabasePicker(
                        context: context,
                        photos: photos,
                        initiallySelectedIds: profilePhoto == null ? const [] : [profilePhoto!.id],
                        initialCoverPhotoId: profilePhoto?.id,
                        title: 'プロフィール画像を選択',
                      );
                      if (result == null) return;
                      setLocalState(() {
                        profilePhoto = result.coverPhoto ?? result.photos.firstOrNull;
                        updateProfilePhoto = true;
                      });
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('写真DBから選択'),
                  ),
                  if (profilePhoto != null)
                    TextButton(onPressed: () => setLocalState(() { profilePhoto = null; updateProfilePhoto = true; }), child: const Text('画像を解除')),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存')),
          ],
        ),
      ),
    );
    if (ok == true && name.trim().isNotEmpty) {
      await repository.updatePerson(person, name.trim(), note.trim(), profilePhoto: profilePhoto, updateProfilePhoto: updateProfilePhoto);
    }
  }

  Future<void> _delete(Person person) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('人物を削除しますか？'),
        content: Text('「${person.name}」を人物DBから削除します。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok == true) {
      await repository.deletePerson(person);
      if (mounted && _selectedPersonId == person.id) setState(() => _selectedPersonId = null);
    }
  }

  Widget _image(Person person, List<PhotoRecord> photos) {
    final photo = _profilePhoto(person, photos);
    if (photo == null) {
      return SizedBox(height: 190, child: ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerLow, child: const Center(child: Icon(Icons.person_outline, size: 52))));
    }
    return Image.file(File(photo.path), width: double.infinity, fit: BoxFit.fitWidth, errorBuilder: (_, __, ___) => const SizedBox(height: 190, child: Center(child: Icon(Icons.person_outline, size: 52))));
  }

  Widget _avatar(Person person, List<PhotoRecord> photos) {
    final photo = _profilePhoto(person, photos);
    return CircleAvatar(radius: 22, backgroundImage: photo == null ? null : FileImage(File(photo.path)), child: photo == null ? const Icon(Icons.person_outline) : null);
  }

  void _showRelated(Person person, List<BookmarkItem> bookmarks) {
    final related = _bookmarksFor(person, bookmarks);
    showBookmarkReverseLookupDialog(
      context: context,
      title: '${person.name} のブックマーク（${related.length}件）',
      bookmarks: repository.watchBookmarksForPerson(person),
    );
  }

  Widget _menu(Person person, List<PhotoRecord> photos, List<BookmarkItem> bookmarks) => PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'detail') setState(() => _selectedPersonId = person.id);
          if (value == 'bookmarks') _showRelated(person, bookmarks);
          if (value == 'edit') _edit(person, photos);
          if (value == 'delete') _delete(person);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'detail', child: Text('詳細を表示')),
          PopupMenuItem(value: 'bookmarks', child: Text('関連ブックマークを見る')),
          PopupMenuItem(value: 'edit', child: Text('プロフィールを編集 / 画像を設定')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Text('削除')),
        ],
      );

  Widget _gallery(List<Person> people, List<PhotoRecord> photos, List<BookmarkItem> bookmarks) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1200 ? 5 : constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 620 ? 3 : 2;
          return MasonryGridView.count(
            padding: const EdgeInsets.fromLTRB(18, UiTokens.space16, 18, 100),
            crossAxisCount: columns,
            mainAxisSpacing: UiTokens.space12,
            crossAxisSpacing: UiTokens.space12,
            itemCount: people.length,
            itemBuilder: (context, index) {
              final person = people[index];
              final related = _bookmarksFor(person, bookmarks);
              final scheme = Theme.of(context).colorScheme;
              final selected = _selectedPersonId == person.id;
              return Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(UiTokens.radiusMd),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _selectedPersonId = person.id),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 1.5 : 1), borderRadius: BorderRadius.circular(UiTokens.radiusMd)),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _image(person, photos),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, UiTokens.space8, UiTokens.space4, 10),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(person.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: UiTokens.space4),
                            Text('${related.length}件のブックマーク', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                            if (person.note?.trim().isNotEmpty == true) ...[const SizedBox(height: UiTokens.space4), Text(person.note!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: UiTokens.textSm, color: scheme.onSurfaceVariant))],
                          ])),
                          _menu(person, photos, bookmarks),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      );

  Widget _list(List<Person> people, List<PhotoRecord> photos, List<BookmarkItem> bookmarks) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, UiTokens.space12, 18, 100),
        itemCount: people.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final person = people[index];
          final related = _bookmarksFor(person, bookmarks);
          return ListTile(
            selected: _selectedPersonId == person.id,
            leading: _avatar(person, photos),
            title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(['${related.length}件のブックマーク', if (person.note?.trim().isNotEmpty == true) person.note!].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: _menu(person, photos, bookmarks),
            onTap: () => setState(() => _selectedPersonId = person.id),
          );
        },
      );

  Widget _table(List<Person> people, List<PhotoRecord> photos, List<BookmarkItem> bookmarks) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, UiTokens.space12, 18, 100),
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [DataColumn(label: Text('人物')), DataColumn(label: Text('メモ')), DataColumn(label: Text('ブックマーク')), DataColumn(label: Text(''))],
          rows: people.map((person) {
            final related = _bookmarksFor(person, bookmarks);
            return DataRow(
              selected: _selectedPersonId == person.id,
              onSelectChanged: (_) => setState(() => _selectedPersonId = person.id),
              cells: [
                DataCell(Row(children: [_avatar(person, photos), const SizedBox(width: 10), Text(person.name)])),
                DataCell(SizedBox(width: 280, child: Text(person.note ?? '', maxLines: 2, overflow: TextOverflow.ellipsis))),
                DataCell(Text('${related.length}件')),
                DataCell(_menu(person, photos, bookmarks)),
              ],
            );
          }).toList(),
        ),
      );

  Widget _detail(Person person, List<PhotoRecord> photos, List<BookmarkItem> bookmarks) {
    final related = _bookmarksFor(person, bookmarks);
    final profilePhoto = _profilePhoto(person, photos);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Column(children: [
        SizedBox(height: UiTokens.toolbarHeight, child: Row(children: [
          const SizedBox(width: UiTokens.space16),
          const Text('人物の詳細', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(tooltip: '編集', onPressed: () => _edit(person, photos), icon: const Icon(Icons.edit_outlined, size: UiTokens.iconNormal)),
          IconButton(tooltip: '閉じる', onPressed: () => setState(() => _selectedPersonId = null), icon: const Icon(Icons.close, size: 19)),
        ])),
        const Divider(height: 1),
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 30), children: [
          if (profilePhoto != null)
            ClipRRect(borderRadius: BorderRadius.circular(UiTokens.radiusMd), child: Image.file(File(profilePhoto.path), width: double.infinity, fit: BoxFit.fitWidth))
          else
            SizedBox(height: 220, child: ColoredBox(color: scheme.surfaceContainerLow, child: const Center(child: Icon(Icons.person_outline, size: 64)))),
          const SizedBox(height: UiTokens.space16),
          Text(person.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: UiTokens.space6),
          Text('${related.length}件の関連ブックマーク', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: UiTokens.space16),
          DetailSection(
            title: '基本情報',
            icon: Icons.person_outline,
            topDivider: false,
            child: person.note?.trim().isNotEmpty == true
                ? Text(person.note!, style: const TextStyle(fontSize: 13.5, height: 1.55))
                : Text('メモはありません', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          DetailSection(
            title: 'Relation',
            icon: Icons.link_outlined,
            trailing: related.isEmpty ? null : TextButton(onPressed: () => _showRelated(person, bookmarks), child: const Text('すべて見る')),
            child: related.isEmpty
                ? Text('関連ブックマークはありません', style: TextStyle(color: scheme.onSurfaceVariant))
                : Column(children: related.take(8).map((bookmark) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bookmark_outline, size: UiTokens.iconNormal),
                    title: Text(bookmark.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(bookmark.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                  )).toList()),
          ),
          DetailSection(
            title: '管理',
            icon: Icons.settings_outlined,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text('人物を削除', style: TextStyle(color: scheme.error)),
              onTap: () => _delete(person),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _viewSwitcher() => SegmentedButton<PeopleViewType>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: PeopleViewType.gallery, icon: Icon(Icons.grid_view, size: 17)),
          ButtonSegment(value: PeopleViewType.list, icon: Icon(Icons.view_list, size: 17)),
          ButtonSegment(value: PeopleViewType.table, icon: Icon(Icons.table_rows, size: 17)),
        ],
        selected: {_viewType},
        onSelectionChanged: (value) => setState(() => _viewType = value.first),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('人物を追加')),
      body: Column(children: [
        DatabasePageToolbar(
          title: '人物',
          searchHint: '人物を検索',
          onSearchChanged: (value) => setState(() => _query = value),
          viewSwitcher: _viewSwitcher(),
        ),
        Expanded(
          child: StreamBuilder<List<Person>>(
            stream: repository.watchPeople(),
            builder: (context, peopleSnapshot) {
              if (!peopleSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              return StreamBuilder<List<PhotoRecord>>(
                stream: repository.watchPhotos(),
                builder: (context, photoSnapshot) {
                  final photos = photoSnapshot.data ?? const <PhotoRecord>[];
                  return StreamBuilder<List<BookmarkItem>>(
                    stream: repository.watchAll(),
                    builder: (context, bookmarkSnapshot) {
                      final bookmarks = bookmarkSnapshot.data ?? const <BookmarkItem>[];
                      final all = peopleSnapshot.data!;
                      final q = _query.trim().toLowerCase();
                      final people = q.isEmpty ? all : all.where((person) => '${person.name} ${person.note ?? ''}'.toLowerCase().contains(q)).toList();
                      final selected = all.where((person) => person.id == _selectedPersonId).firstOrNull;
                      if (all.isEmpty && selected == null) {
                        return AppEmptyState(
                          icon: Icons.people_outline,
                          title: '人物はまだありません',
                          message: '著者・出演者・講師などを人物DBとして登録すると、ブックマークからRelationできます。',
                          actionLabel: '人物を追加',
                          onAction: _create,
                        );
                      }
                      return Row(children: [
                        Expanded(
                          child: people.isEmpty
                              ? const AppEmptyState(icon: Icons.search_off_outlined, title: '検索条件に一致する人物がいません')
                              : switch (_viewType) {
                                  PeopleViewType.gallery => _gallery(people, photos, bookmarks),
                                  PeopleViewType.list => _list(people, photos, bookmarks),
                                  PeopleViewType.table => _table(people, photos, bookmarks),
                                },
                        ),
                        if (selected != null) ...[
                          const VerticalDivider(width: 1),
                          SizedBox(width: 400, child: _detail(selected, photos, bookmarks)),
                        ],
                      ]);
                    },
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
