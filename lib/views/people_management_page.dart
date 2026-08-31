import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../widgets/bookmark_reverse_lookup_dialog.dart';
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

  BookmarkRepository get repository => widget.repository;

  Future<void> _create(BuildContext context) async {
    final name = TextEditingController();
    final note = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('人物を追加'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: '名前')),
            const SizedBox(height: 10),
            TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'メモ')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await repository.createPerson(name.text.trim(), note: note.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
    name.dispose();
    note.dispose();
  }

  Future<void> _edit(BuildContext context, Person person, List<PhotoRecord> allPhotos) async {
    final name = TextEditingController(text: person.name);
    final note = TextEditingController(text: person.note ?? '');
    PhotoRecord? profilePhoto = allPhotos.where((photo) => photo.id == person.profilePhotoId).firstOrNull;
    var updateProfilePhoto = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('人物プロフィールを編集'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: '名前')),
                const SizedBox(height: 10),
                TextField(controller: note, maxLines: 4, decoration: const InputDecoration(labelText: 'メモ')),
                const SizedBox(height: 18),
                const Text('サムネイル / プロフィール画像', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (profilePhoto != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 180, height: 180, child: Image.file(File(profilePhoto!.path), fit: BoxFit.cover)),
                  )
                else
                  Container(
                    width: 180,
                    height: 180,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.person_outline, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await showPhotoDatabasePicker(
                        context: context,
                        photos: allPhotos,
                        initiallySelectedIds: profilePhoto == null ? const [] : [profilePhoto!.id],
                        initialCoverPhotoId: profilePhoto?.id,
                        title: 'サムネイル画像を選択',
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
                    TextButton(
                      onPressed: () => setLocalState(() {
                        profilePhoto = null;
                        updateProfilePhoto = true;
                      }),
                      child: const Text('画像を解除'),
                    ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await repository.updatePerson(
                  person,
                  name.text.trim(),
                  note.text.trim(),
                  profilePhoto: profilePhoto,
                  updateProfilePhoto: updateProfilePhoto,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    note.dispose();
  }

  Future<void> _delete(BuildContext context, Person person) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('人物を削除しますか？'),
        content: Text('「${person.name}」を人物DBから削除します。ブックマーク自体は削除されません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok == true) await repository.deletePerson(person);
  }

  PhotoRecord? _profilePhoto(Person person, List<PhotoRecord> photos) =>
      photos.where((photo) => photo.id == person.profilePhotoId).firstOrNull;

  Widget _thumbnail(Person person, List<PhotoRecord> photos, {BoxFit fit = BoxFit.cover}) {
    final photo = _profilePhoto(person, photos);
    if (photo != null) {
      return Image.file(
        File(photo.path),
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (_, __, ___) => _thumbnailPlaceholder(),
      );
    }
    return _thumbnailPlaceholder();
  }

  Widget _thumbnailPlaceholder() => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Center(child: Icon(Icons.person_outline, size: 52, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _avatar(Person person, List<PhotoRecord> photos, {double radius = 22}) {
    final photo = _profilePhoto(person, photos);
    if (photo == null) return CircleAvatar(radius: radius, child: const Icon(Icons.person_outline));
    return CircleAvatar(radius: radius, backgroundImage: FileImage(File(photo.path)));
  }

  List<BookmarkItem> _bookmarksFor(Person person, List<BookmarkItem> bookmarks) =>
      bookmarks.where((bookmark) => bookmark.people.any((candidate) => candidate.id == person.id)).toList();

  List<PhotoRecord> _relatedPhotos(Person person, List<BookmarkItem> bookmarks, List<PhotoRecord> allPhotos) {
    final ids = <int>{};
    if (person.profilePhotoId != null) ids.add(person.profilePhotoId!);
    for (final bookmark in _bookmarksFor(person, bookmarks)) {
      ids.addAll(bookmark.photos.map((photo) => photo.id));
    }
    return allPhotos.where((photo) => ids.contains(photo.id)).toList();
  }

  Future<void> _showProfile(BuildContext context, Person person, List<PhotoRecord> photos, List<BookmarkItem> allBookmarks) async {
    final relatedBookmarks = _bookmarksFor(person, allBookmarks);
    final relatedPhotos = _relatedPhotos(person, allBookmarks, photos);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(children: [
                const Text('人物プロフィール', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(tooltip: '編集', onPressed: () async { Navigator.pop(dialogContext); await _edit(context, person, photos); }, icon: const Icon(Icons.edit_outlined, size: 19)),
                IconButton(tooltip: '閉じる', onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 170, height: 170, child: _thumbnail(person, photos))),
                    const SizedBox(width: 22),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(person.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('${relatedBookmarks.length}件のブックマーク · ${relatedPhotos.length}枚の関連写真', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      if (person.note?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 18),
                        Text(person.note!, style: const TextStyle(fontSize: 14, height: 1.55)),
                      ],
                    ])),
                  ]),
                  const SizedBox(height: 28),
                  Row(children: [
                    const Text('関連ブックマーク', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (relatedBookmarks.isNotEmpty)
                      TextButton(
                        onPressed: () => showBookmarkReverseLookupDialog(
                          context: context,
                          title: '${person.name} のブックマーク（${relatedBookmarks.length}件）',
                          bookmarks: repository.watchBookmarksForPerson(person),
                        ),
                        child: const Text('すべて見る'),
                      ),
                  ]),
                  if (relatedBookmarks.isEmpty)
                    Text('関連ブックマークはありません', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
                  else
                    ...relatedBookmarks.take(6).map((bookmark) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bookmark_outline, size: 19),
                      title: Text(bookmark.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(bookmark.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    )),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context, Person person, List<PhotoRecord> photos, List<BookmarkItem> bookmarks) {
    final relatedBookmarks = _bookmarksFor(person, bookmarks);
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'profile') _showProfile(context, person, photos, bookmarks);
        if (value == 'bookmarks') {
          showBookmarkReverseLookupDialog(
            context: context,
            title: '${person.name} のブックマーク（${relatedBookmarks.length}件）',
            bookmarks: repository.watchBookmarksForPerson(person),
          );
        }
        if (value == 'edit') _edit(context, person, photos);
        if (value == 'delete') _delete(context, person);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'profile', child: Text('プロフィールを見る')),
        PopupMenuItem(value: 'bookmarks', child: Text('関連ブックマークを見る')),
        PopupMenuItem(value: 'edit', child: Text('プロフィールを編集 / 画像を設定')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Text('削除')),
      ],
    );
  }

  Widget _gallery(List<Person> people, List<PhotoRecord> photos, List<BookmarkItem> bookmarks) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1200 ? 5 : constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 620 ? 3 : 2;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .78),
        itemCount: people.length,
        itemBuilder: (context, index) {
          final person = people[index];
          final related = _bookmarksFor(person, bookmarks);
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showProfile(context, person, photos, bookmarks),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: SizedBox(width: double.infinity, child: _thumbnail(person, photos))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('${related.length}件のブックマーク', style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      if (person.note?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 5),
                        Text(person.note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ])),
                    _menu(context, person, photos, bookmarks),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
    });
  }

  Widget _list(List<Person> people, List<PhotoRecord> photos, List<BookmarkItem> bookmarks) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: people.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final person = people[index];
        final relatedBookmarks = _bookmarksFor(person, bookmarks);
        final relatedPhotos = _relatedPhotos(person, bookmarks, photos);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          leading: _avatar(person, photos, radius: 24),
          title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            ['${relatedBookmarks.length}件のブックマーク', '${relatedPhotos.length}枚の関連写真', if (person.note?.trim().isNotEmpty == true) person.note!].join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _showProfile(context, person, photos, bookmarks),
          trailing: _menu(context, person, photos, bookmarks),
        );
      },
    );
  }

  Widget _table(List<Person> people, List<PhotoRecord> photos, List<BookmarkItem> bookmarks) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('画像')),
          DataColumn(label: Text('名前')),
          DataColumn(label: Text('ブックマーク')),
          DataColumn(label: Text('関連写真')),
          DataColumn(label: Text('メモ')),
          DataColumn(label: Text('')),
        ],
        rows: people.map((person) {
          final relatedBookmarks = _bookmarksFor(person, bookmarks);
          final relatedPhotos = _relatedPhotos(person, bookmarks, photos);
          return DataRow(
            onSelectChanged: (_) => _showProfile(context, person, photos, bookmarks),
            cells: [
              DataCell(ClipRRect(borderRadius: BorderRadius.circular(5), child: SizedBox(width: 52, height: 42, child: _thumbnail(person, photos)))),
              DataCell(Text(person.name)),
              DataCell(Text('${relatedBookmarks.length}件')),
              DataCell(Text('${relatedPhotos.length}枚')),
              DataCell(SizedBox(width: 260, child: Text(person.note ?? '', maxLines: 2, overflow: TextOverflow.ellipsis))),
              DataCell(_menu(context, person, photos, bookmarks)),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('人物DB'),
        actions: [
          SizedBox(
            width: 210,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: '人物を検索'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SegmentedButton<PeopleViewType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: PeopleViewType.gallery, icon: Icon(Icons.grid_view, size: 17)),
              ButtonSegment(value: PeopleViewType.list, icon: Icon(Icons.view_list, size: 17)),
              ButtonSegment(value: PeopleViewType.table, icon: Icon(Icons.table_rows, size: 17)),
            ],
            selected: {_viewType},
            onSelectionChanged: (value) => setState(() => _viewType = value.first),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('人物を追加'),
      ),
      body: StreamBuilder<List<Person>>(
        stream: repository.watchPeople(),
        builder: (context, peopleSnapshot) {
          if (!peopleSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<List<PhotoRecord>>(
            stream: repository.watchPhotos(),
            builder: (context, photoSnapshot) => StreamBuilder<List<BookmarkItem>>(
              stream: repository.watchAll(),
              builder: (context, bookmarkSnapshot) {
                final query = _query.trim().toLowerCase();
                final people = peopleSnapshot.data!
                    .where((person) => query.isEmpty || person.name.toLowerCase().contains(query) || (person.note?.toLowerCase().contains(query) ?? false))
                    .toList();
                final photos = photoSnapshot.data ?? const <PhotoRecord>[];
                final bookmarks = bookmarkSnapshot.data ?? const <BookmarkItem>[];
                if (people.isEmpty) return Center(child: Text(query.isEmpty ? '人物がまだ登録されていません。' : '一致する人物がいません。'));
                return switch (_viewType) {
                  PeopleViewType.gallery => _gallery(people, photos, bookmarks),
                  PeopleViewType.list => _list(people, photos, bookmarks),
                  PeopleViewType.table => _table(people, photos, bookmarks),
                };
              },
            ),
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
