import 'package:flutter/material.dart';

import '../data/app_database.dart';

typedef CreateTagFromPicker = Future<Tag?> Function(String name, Tag? parent);
typedef CreatePersonFromPicker = Future<Person?> Function(String name, String? note);

Future<List<Tag>?> showTagDatabasePicker({
  required BuildContext context,
  required List<Tag> tags,
  required Iterable<int> initiallySelectedIds,
  CreateTagFromPicker? onCreateTag,
}) {
  final allTags = <Tag>[...tags];
  final selected = initiallySelectedIds.toSet();
  var query = '';

  List<Tag> childrenOf(int? parentId) => allTags
      .where((tag) => tag.parentTagId == parentId)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<({Tag tag, int depth})> flatten() {
    final result = <({Tag tag, int depth})>[];
    final visited = <int>{};

    void visit(int? parentId, int depth) {
      for (final tag in childrenOf(parentId)) {
        if (!visited.add(tag.id)) continue;
        result.add((tag: tag, depth: depth));
        visit(tag.id, depth + 1);
      }
    }

    visit(null, 0);
    for (final tag in allTags) {
      if (visited.add(tag.id)) result.add((tag: tag, depth: 0));
    }
    return result;
  }

  Future<Tag?> createTag(BuildContext dialogContext) async {
    if (onCreateTag == null) return null;
    var name = query.trim();
    Tag? parent;
    final created = await showDialog<Tag?>(
      context: dialogContext,
      builder: (createContext) => StatefulBuilder(
        builder: (context, setCreateState) => AlertDialog(
          title: const Text('新しいタグを作成'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'タグ名'),
                  onChanged: (value) => name = value,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Tag?>(
                  initialValue: parent,
                  decoration: const InputDecoration(labelText: '親タグ（任意）'),
                  items: [
                    const DropdownMenuItem<Tag?>(value: null, child: Text('最上位')),
                    ...allTags.map((tag) => DropdownMenuItem<Tag?>(value: tag, child: Text(tag.name))),
                  ],
                  onChanged: (value) => setCreateState(() => parent = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(createContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () async {
                final value = name.trim();
                if (value.isEmpty) return;
                final result = await onCreateTag(value, parent);
                if (createContext.mounted) Navigator.pop(createContext, result);
              },
              child: const Text('作成'),
            ),
          ],
        ),
      ),
    );
    return created;
  }

  return showDialog<List<Tag>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        final normalizedQuery = query.trim().toLowerCase();
        final entries = flatten()
            .where((entry) =>
                normalizedQuery.isEmpty ||
                entry.tag.name.toLowerCase().contains(normalizedQuery))
            .toList();

        return AlertDialog(
          title: const Text('タグDBから選択'),
          content: SizedBox(
            width: 560,
            height: 520,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (value) => setLocalState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: 'タグを検索',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (onCreateTag != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final created = await createTag(dialogContext);
                        if (created == null) return;
                        setLocalState(() {
                          if (!allTags.any((tag) => tag.id == created.id)) allTags.add(created);
                          selected.add(created.id);
                          query = '';
                        });
                      },
                      icon: const Icon(Icons.add, size: 17),
                      label: Text(query.trim().isEmpty ? '新しいタグを作成' : '「${query.trim()}」を新規作成'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(child: Text('一致するタグがありません'))
                      : ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final checked = selected.contains(entry.tag.id);
                            return CheckboxListTile(
                              value: checked,
                              contentPadding: EdgeInsets.only(
                                left: 8 + entry.depth * 22,
                                right: 8,
                              ),
                              secondary: Icon(
                                childrenOf(entry.tag.id).isEmpty
                                    ? Icons.sell_outlined
                                    : Icons.folder_outlined,
                                size: 18,
                              ),
                              title: Text(entry.tag.name),
                              controlAffinity: ListTileControlAffinity.trailing,
                              onChanged: (value) => setLocalState(() {
                                if (value == true) {
                                  selected.add(entry.tag.id);
                                } else {
                                  selected.remove(entry.tag.id);
                                }
                              }),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${selected.length} 件選択中'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setLocalState(selected.clear),
              child: const Text('すべて解除'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                allTags.where((tag) => selected.contains(tag.id)).toList(),
              ),
              child: const Text('選択'),
            ),
          ],
        );
      },
    ),
  );
}

Future<List<Person>?> showPeopleDatabasePicker({
  required BuildContext context,
  required List<Person> people,
  required Iterable<int> initiallySelectedIds,
  CreatePersonFromPicker? onCreatePerson,
}) {
  final allPeople = <Person>[...people];
  final selected = initiallySelectedIds.toSet();
  var query = '';

  Future<Person?> createPerson(BuildContext dialogContext) async {
    if (onCreatePerson == null) return null;
    var name = query.trim();
    var note = '';
    return showDialog<Person?>(
      context: dialogContext,
      builder: (createContext) => AlertDialog(
        title: const Text('新しい人物を作成'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: '名前'),
                onChanged: (value) => name = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'メモ（任意）'),
                maxLines: 3,
                onChanged: (value) => note = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(createContext), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final value = name.trim();
              if (value.isEmpty) return;
              final result = await onCreatePerson(value, note.trim().isEmpty ? null : note.trim());
              if (createContext.mounted) Navigator.pop(createContext, result);
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  return showDialog<List<Person>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        final normalizedQuery = query.trim().toLowerCase();
        final filtered = allPeople.where((person) {
          if (normalizedQuery.isEmpty) return true;
          return person.name.toLowerCase().contains(normalizedQuery) ||
              (person.note ?? '').toLowerCase().contains(normalizedQuery);
        }).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return AlertDialog(
          title: const Text('人物DBから選択'),
          content: SizedBox(
            width: 560,
            height: 520,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (value) => setLocalState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: '人物名・メモを検索',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (onCreatePerson != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final created = await createPerson(dialogContext);
                        if (created == null) return;
                        setLocalState(() {
                          if (!allPeople.any((person) => person.id == created.id)) allPeople.add(created);
                          selected.add(created.id);
                          query = '';
                        });
                      },
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
                      label: Text(query.trim().isEmpty ? '新しい人物を作成' : '「${query.trim()}」を新規作成'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('一致する人物がいません'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final person = filtered[index];
                            final checked = selected.contains(person.id);
                            return CheckboxListTile(
                              value: checked,
                              secondary: const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              title: Text(person.name),
                              subtitle: person.note?.trim().isNotEmpty == true
                                  ? Text(
                                      person.note!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              controlAffinity: ListTileControlAffinity.trailing,
                              onChanged: (value) => setLocalState(() {
                                if (value == true) {
                                  selected.add(person.id);
                                } else {
                                  selected.remove(person.id);
                                }
                              }),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${selected.length} 人選択中'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setLocalState(selected.clear),
              child: const Text('すべて解除'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                allPeople.where((person) => selected.contains(person.id)).toList(),
              ),
              child: const Text('選択'),
            ),
          ],
        );
      },
    ),
  );
}
