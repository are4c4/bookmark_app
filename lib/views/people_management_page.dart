import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';

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

  Future<void> _edit(BuildContext context, Person person) async {
    final name = TextEditingController(text: person.name);
    final note = TextEditingController(text: person.note ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('出演者を編集'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: '名前')),
              TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'メモ')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              await repository.updatePerson(person, name.text, note.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('保存'),
          ),
        ],
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

              if (people.isEmpty) {
                return const Center(child: Text('出演者がまだ登録されていません。'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: people.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final person = people[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(person.name),
                    subtitle: Text(
                      [
                        '${counts[person.id] ?? 0} 件のブックマーク',
                        if (person.note?.trim().isNotEmpty == true) person.note!,
                      ].join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _edit(context, person);
                        if (value == 'delete') _delete(context, person);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('編集')),
                        PopupMenuItem(value: 'delete', child: Text('削除')),
                      ],
                    ),
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
