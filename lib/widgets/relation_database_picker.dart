import 'package:flutter/material.dart';

import '../data/app_database.dart';

typedef CreateTagFromPicker = Future<Tag?> Function(String name, Tag? parent);
typedef CreatePersonFromPicker = Future<Person?> Function(String name, String? note);

Future<List<Tag>?> showTagDatabasePicker({
  required BuildContext context,
  required List<Tag> tags,
  required Iterable<int> initiallySelectedIds,
  CreateTagFromPicker? onCreateTag,
}) async {
  final allTags = <Tag>[...tags];
  final selected = initiallySelectedIds.toSet();
  final controller = TextEditingController();
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

  Tag? exactMatch(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final tag in allTags) {
      if (tag.name.trim().toLowerCase() == normalized) return tag;
    }
    return null;
  }

  Future<Tag?> createWithParent(BuildContext dialogContext) async {
    if (onCreateTag == null) return null;
    var name = query.trim();
    Tag? parent;
    return showDialog<Tag?>(
      context: dialogContext,
      builder: (createContext) => StatefulBuilder(
        builder: (context, setCreateState) => AlertDialog(
          title: const Text('親を指定してタグを作成'),
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
                    const DropdownMenuItem<Tag?>(
                      value: null,
                      child: Text('最上位'),
                    ),
                    ...allTags.map(
                      (tag) => DropdownMenuItem<Tag?>(
                        value: tag,
                        child: Text(tag.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setCreateState(() => parent = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(createContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                final value = name.trim();
                if (value.isEmpty) return;
                final existing = exactMatch(value);
                if (existing != null) {
                  Navigator.pop(createContext, existing);
                  return;
                }
                final created = await onCreateTag(value, parent);
                if (createContext.mounted) {
                  Navigator.pop(createContext, created);
                }
              },
              child: const Text('作成'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> quickSelectOrCreate(
    String rawValue,
    StateSetter setLocalState,
  ) async {
    final value = rawValue.trim();
    if (value.isEmpty) return;
    final existing = exactMatch(value);
    if (existing != null) {
      setLocalState(() {
        selected.add(existing.id);
        query = '';
        controller.clear();
      });
      return;
    }
    if (onCreateTag == null) return;
    final created = await onCreateTag(value, null);
    if (created == null) return;
    setLocalState(() {
      if (!allTags.any((tag) => tag.id == created.id)) allTags.add(created);
      selected.add(created.id);
      query = '';
      controller.clear();
    });
  }

  final result = await showDialog<List<Tag>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocalState) {
        final normalizedQuery = query.trim().toLowerCase();
        final entries = flatten()
            .where(
              (entry) =>
                  normalizedQuery.isEmpty ||
                  entry.tag.name.toLowerCase().contains(normalizedQuery),
            )
            .toList();
        final exact = exactMatch(query);
        final scheme = Theme.of(context).colorScheme;

        void toggle(Tag tag) => setLocalState(() {
              if (!selected.remove(tag.id)) selected.add(tag.id);
            });

        return AlertDialog(
          title: const Text('タグDBから選択'),
          content: SizedBox(
            width: 560,
            height: 520,
            child: Column(
              children: [
                if (selected.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: allTags
                          .where((tag) => selected.contains(tag.id))
                          .map(
                            (tag) => InputChip(
                              label: Text(tag.name),
                              onDeleted: () => setLocalState(
                                () => selected.remove(tag.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onChanged: (value) => setLocalState(() => query = value),
                  onSubmitted: (value) =>
                      quickSelectOrCreate(value, setLocalState),
                  decoration: InputDecoration(
                    hintText: onCreateTag == null
                        ? 'タグを検索'
                        : 'タグを検索・入力してEnterで追加',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'クリア',
                            onPressed: () => setLocalState(() {
                              query = '';
                              controller.clear();
                            }),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (onCreateTag != null && query.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('tag-picker-quick-action'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => quickSelectOrCreate(query, setLocalState),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            Icon(exact == null ? Icons.add : Icons.check, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                exact == null
                                    ? '「${query.trim()}」を作成  ·  Enter'
                                    : '「${exact.name}」を選択  ·  Enter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (exact == null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final created = await createWithParent(dialogContext);
                          if (created == null) return;
                          setLocalState(() {
                            if (!allTags.any((tag) => tag.id == created.id)) {
                              allTags.add(created);
                            }
                            selected.add(created.id);
                            query = '';
                            controller.clear();
                          });
                        },
                        icon: const Icon(Icons.account_tree_outlined, size: 16),
                        label: const Text('親を指定して作成…'),
                      ),
                    ),
                ] else if (onCreateTag != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '名前を入力して Enter で作成・選択',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            query.trim().isEmpty
                                ? 'タグがありません'
                                : onCreateTag == null
                                    ? '一致するタグがありません'
                                    : 'Enterで「${query.trim()}」を作成',
                          ),
                        )
                      : ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final checked = selected.contains(entry.tag.id);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Material(
                                color: checked
                                    ? scheme.secondaryContainer.withValues(alpha: .45)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                child: InkWell(
                                  key: ValueKey('tag-picker-row:${entry.tag.id}'),
                                  borderRadius: BorderRadius.circular(5),
                                  onTap: () => toggle(entry.tag),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: 10 + entry.depth * 22,
                                      right: 10,
                                      top: 9,
                                      bottom: 9,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          childrenOf(entry.tag.id).isEmpty
                                              ? Icons.sell_outlined
                                              : Icons.folder_outlined,
                                          size: 18,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(entry.tag.name)),
                                        if (checked)
                                          const Icon(Icons.check, size: 19),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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

  controller.dispose();
  return result;
}

Future<List<Person>?> showPeopleDatabasePicker({
  required BuildContext context,
  required List<Person> people,
  required Iterable<int> initiallySelectedIds,
  CreatePersonFromPicker? onCreatePerson,
}) async {
  final allPeople = <Person>[...people];
  final selected = initiallySelectedIds.toSet();
  final controller = TextEditingController();
  var query = '';

  Person? exactMatch(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final person in allPeople) {
      if (person.name.trim().toLowerCase() == normalized) return person;
    }
    return null;
  }

  Future<Person?> createWithDetails(BuildContext dialogContext) async {
    if (onCreatePerson == null) return null;
    var name = query.trim();
    var note = '';
    return showDialog<Person?>(
      context: dialogContext,
      builder: (createContext) => AlertDialog(
        title: const Text('詳細を入力して人物を作成'),
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
          TextButton(
            onPressed: () => Navigator.pop(createContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              final value = name.trim();
              if (value.isEmpty) return;
              final existing = exactMatch(value);
              if (existing != null) {
                Navigator.pop(createContext, existing);
                return;
              }
              final created = await onCreatePerson(
                value,
                note.trim().isEmpty ? null : note.trim(),
              );
              if (createContext.mounted) {
                Navigator.pop(createContext, created);
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  Future<void> quickSelectOrCreate(
    String rawValue,
    StateSetter setLocalState,
  ) async {
    final value = rawValue.trim();
    if (value.isEmpty) return;
    final existing = exactMatch(value);
    if (existing != null) {
      setLocalState(() {
        selected.add(existing.id);
        query = '';
        controller.clear();
      });
      return;
    }
    if (onCreatePerson == null) return;
    final created = await onCreatePerson(value, null);
    if (created == null) return;
    setLocalState(() {
      if (!allPeople.any((person) => person.id == created.id)) {
        allPeople.add(created);
      }
      selected.add(created.id);
      query = '';
      controller.clear();
    });
  }

  final result = await showDialog<List<Person>>(
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
        final exact = exactMatch(query);
        final scheme = Theme.of(context).colorScheme;

        void toggle(Person person) => setLocalState(() {
              if (!selected.remove(person.id)) selected.add(person.id);
            });

        return AlertDialog(
          title: const Text('人物DBから選択'),
          content: SizedBox(
            width: 560,
            height: 520,
            child: Column(
              children: [
                if (selected.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: allPeople
                          .where((person) => selected.contains(person.id))
                          .map(
                            (person) => InputChip(
                              avatar: const Icon(Icons.person_outline, size: 15),
                              label: Text(person.name),
                              onDeleted: () => setLocalState(
                                () => selected.remove(person.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onChanged: (value) => setLocalState(() => query = value),
                  onSubmitted: (value) =>
                      quickSelectOrCreate(value, setLocalState),
                  decoration: InputDecoration(
                    hintText: onCreatePerson == null
                        ? '人物名・メモを検索'
                        : '人物を検索・名前を入力してEnterで追加',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (onCreatePerson != null && query.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('person-picker-quick-action'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => quickSelectOrCreate(query, setLocalState),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            Icon(exact == null ? Icons.add : Icons.check, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                exact == null
                                    ? '「${query.trim()}」を作成  ·  Enter'
                                    : '「${exact.name}」を選択  ·  Enter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (exact == null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          final created = await createWithDetails(dialogContext);
                          if (created == null) return;
                          setLocalState(() {
                            if (!allPeople.any((person) => person.id == created.id)) {
                              allPeople.add(created);
                            }
                            selected.add(created.id);
                            query = '';
                            controller.clear();
                          });
                        },
                        icon: const Icon(Icons.edit_note_outlined, size: 16),
                        label: const Text('メモも入力して作成…'),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            query.trim().isEmpty
                                ? '人物がいません'
                                : onCreatePerson == null
                                    ? '一致する人物がいません'
                                    : 'Enterで「${query.trim()}」を作成',
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final person = filtered[index];
                            final checked = selected.contains(person.id);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Material(
                                color: checked
                                    ? scheme.secondaryContainer.withValues(alpha: .45)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                child: InkWell(
                                  key: ValueKey('person-picker-row:${person.id}'),
                                  borderRadius: BorderRadius.circular(5),
                                  onTap: () => toggle(person),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 17,
                                          child: Icon(Icons.person_outline, size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(person.name),
                                              if (person.note?.trim().isNotEmpty == true)
                                                Text(
                                                  person.note!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: scheme.onSurfaceVariant,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (checked)
                                          const Icon(Icons.check, size: 19),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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

  controller.dispose();
  return result;
}
