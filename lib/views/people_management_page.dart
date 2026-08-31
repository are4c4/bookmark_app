import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../widgets/bookmark_reverse_lookup_dialog.dart';
import '../widgets/photo_database_picker.dart';

class PeopleManagementPage extends StatelessWidget {
  const PeopleManagementPage({super.key, required this.repository});

  final BookmarkRepository repository;

  Future<void> _create(BuildContext context) async {
    final name = TextEditingController();
    final note = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('出演者を追加'),
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
          title: const Text('出演者プロフィールを編集'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: '名前')),
                const SizedBox(height: 10),
                TextField(controller: note, maxLines: 4, decoration: const InputDecoration(labelText: 'メモ')),
                const SizedBox(height: 18),
                const Text('プロフィール画像', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (profilePhoto != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 160, height: 160, child: Image.file(File(profilePhoto!.path), fit: BoxFit.cover)),
                  )
                else
                  Container(
                    width: 160,
                    height: 160,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFF7F7F5), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.person_outline, size: 52, color: Color(0xFF9B9A97)),
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
        title: const Text('出演者を削除しますか？'),
        content: Text('「${person.name}」を出演者DBから削除します。ブックマーク自体は削除されません。'),
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

  Future<void> _showProfile(
    BuildContext context,
    Person person,
    List<PhotoRecord> photos,
    List<BookmarkItem> allBookmarks,
  ) async {
    final relatedBookmarks = _bookmarksFor(person, allBookmarks);
    final relatedPhotos = _relatedPhotos(person, allBookmarks, photos);
    final profilePhoto = _profilePhoto(person, photos);

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
                const Text('出演者プロフィール', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF787774))),
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
                    if (profilePhoto != null)
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 150, height: 150, child: Image.file(File(profilePhoto.path), fit: BoxFit.cover)))
                    else
                      Container(width: 150, height: 150, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFF7F7F5), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person_outline, size: 52, color: Color(0xFF9B9A97))),
                    const SizedBox(width: 22),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(person.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF37352F))),
                      const SizedBox(height: 8),
                      Text('${relatedBookmarks.length}件のブックマーク · ${relatedPhotos.length}枚の関連写真', style: const TextStyle(fontSize: 13, color: Color(0xFF9B9A97))),
                      if (person.note?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 18),
                        Text(person.note!, style: const TextStyle(fontSize: 14, height: 1.55, color: Color(0xFF565653))),
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
                  const SizedBox(height: 8),
                  if (relatedBookmarks.isEmpty)
                    const Text('関連ブックマークはありません', style: TextStyle(color: Color(0xFF9B9A97)))
                  else
                    ...relatedBookmarks.take(6).map((bookmark) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bookmark_outline, size: 19),
                      title: Text(bookmark.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(bookmark.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    )),
                  const SizedBox(height: 24),
                  const Text('関連写真', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  if (relatedPhotos.isEmpty)
                    const Text('関連写真はありません', style: TextStyle(color: Color(0xFF9B9A97)))
                  else
                    LayoutBuilder(builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final itemWidth = width < 500 ? 110.0 : 140.0;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: relatedPhotos.map((photo) => SizedBox(
                          width: itemWidth,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: Image.file(File(photo.path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(photo.title?.trim().isNotEmpty == true ? photo.title! : '写真', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          ]),
                        )).toList(),
                      );
                    }),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('出演者DB')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('出演者を追加'),
      ),
      body: StreamBuilder<List<Person>>(
        stream: repository.watchPeople(),
        builder: (context, peopleSnapshot) {
          if (!peopleSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final people = peopleSnapshot.data!;
          return StreamBuilder<List<PhotoRecord>>(
            stream: repository.watchPhotos(),
            builder: (context, photoSnapshot) {
              final photos = photoSnapshot.data ?? const <PhotoRecord>[];
              return StreamBuilder<List<BookmarkItem>>(
                stream: repository.watchAll(),
                builder: (context, bookmarkSnapshot) {
                  final bookmarks = bookmarkSnapshot.data ?? const <BookmarkItem>[];
                  if (people.isEmpty) return const Center(child: Text('出演者がまだ登録されていません。'));

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
                          [
                            '${relatedBookmarks.length}件のブックマーク',
                            '${relatedPhotos.length}枚の関連写真',
                            if (person.note?.trim().isNotEmpty == true) person.note!,
                          ].join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _showProfile(context, person, photos, bookmarks),
                        trailing: PopupMenuButton<String>(
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
                            PopupMenuItem(value: 'edit', child: Text('プロフィールを編集')),
                            PopupMenuDivider(),
                            PopupMenuItem(value: 'delete', child: Text('削除')),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
