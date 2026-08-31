import 'package:flutter/material.dart';

import '../data/app_database.dart';

Future<List<Tag>?> showTagDatabasePicker({
  required BuildContext context,
  required List<Tag> tags,
  required Iterable<int> initiallySelectedIds,
}) {
  final selected = initiallySelectedIds.toSet();
  var query = '';

  List<Tag> childrenOf(int? parentId) => tags
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
    for (final tag in tags) {
      if (visited.add(tag.id)) result.add((tag: tag, depth: 0));
    }
    return result;
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
                const SizedBox(height: 12),
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
                tags.where((tag) => selected.contains(tag.id)).toList(),
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
}) {
  final selected = initiallySelectedIds.toSet();
  var query = '';

  return showDialog<List<Person>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        final normalizedQuery = query.trim().toLowerCase();
        final filtered = people.where((person) {
          if (normalizedQuery.isEmpty) return true;
          return person.name.toLowerCase().contains(normalizedQuery) ||
              (person.note ?? '').toLowerCase().contains(normalizedQuery);
        }).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return AlertDialog(
          title: const Text('出演者DBから選択'),
          content: SizedBox(
            width: 560,
            height: 520,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (value) => setLocalState(() => query = value),
                  decoration: const InputDecoration(
                    hintText: '出演者名・メモを検索',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('一致する出演者がいません'))
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
                people.where((person) => selected.contains(person.id)).toList(),
              ),
              child: const Text('選択'),
            ),
          ],
        );
      },
    ),
  );
}
