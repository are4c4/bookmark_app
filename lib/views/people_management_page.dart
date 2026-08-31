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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: '名前')),
              TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'メモ')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await repository.createPerson(name.text, note: note.text);
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
          title: const Text('出演者を編集'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: '名前')),
                  TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'メモ')),
                  const SizedBox(height: 18),
                  const Text('プロフィール画像', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (profilePhoto != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(width: 150, height: 150, child: Image.file(File(profilePhoto!.path), fit: BoxFit.cover)),
                    )
                  else
                    Container(
                      width: 150,
                      height: 150,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFF7F7F5), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.person_outline, size: 48, color: Color(0xFF9B9A97)),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
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
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () async {
                await repository.updatePerson(
                  person,
                  name.text,
                  note.text,
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
        content: Text('「${person.name}」を出演者DBから削除します。動画・ブックマーク自体は削除されません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok == true) await repository.deletePerson(person);
  }

  Widget _avatar(Person person, List<PhotoRecord> photos) {
    final photo = photos.where((candidate) => candidate.id == person.profilePhotoId).firstOrNull;
    if (photo == null) return const CircleAvatar(child: Icon(Icons.person_outline));
    return CircleAvatar(backgroundImage: FileImage(File(photo.path)));
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
                  final counts = <int, int>{};
                  for (final bookmark in bookmarks) {
                    for (final person in bookmark.people) {
                      counts[person.id] = (counts[person.id] ?? 0) + 1;
                    }
                  }

                  if (people.isEmpty) return const Center(child: Text('出演者がまだ登録されていません。'));

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    itemCount: people.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      final count = counts[person.id] ?? 0;
                      return ListTile(
                        leading: _avatar(person, photos),
                        title: Text(person.name),
                        subtitle: Text(
                          ['$count 件のブックマーク', if (person.note?.trim().isNotEmpty == true) person.note!].join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => showBookmarkReverseLookupDialog(
                          context: context,
                          title: '${person.name} のブックマーク（$count件）',
                          bookmarks: repository.watchBookmarksForPerson(person),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'bookmarks') {
                              showBookmarkReverseLookupDialog(
                                context: context,
                                title: '${person.name} のブックマーク（$count件）',
                                bookmarks: repository.watchBookmarksForPerson(person),
                              );
                            }
                            if (value == 'edit') _edit(context, person, photos);
                            if (value == 'delete') _delete(context, person);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'bookmarks', child: Text('関連ブックマークを見る')),
                            PopupMenuItem(value: 'edit', child: Text('プロフィールを編集')),
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
