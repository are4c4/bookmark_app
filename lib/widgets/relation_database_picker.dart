import 'package:flutter/material.dart';

import '../data/app_database.dart';

typedef CreateTagFromPicker = Future<Tag?> Function(String name, Tag? parent);
typedef CreatePersonFromPicker = Future<Person?> Function(
  String name,
  String? note,
);

Future<List<Tag>?> showTagDatabasePicker({
  required BuildContext context,
  required List<Tag> tags,
  required Iterable<int> initiallySelectedIds,
  CreateTagFromPicker? onCreateTag,
}) async {
  final allTags = <Tag>[...tags];
  final selected = initiallySelectedIds.toSet();
  await showDialog<void>(
    context: context,
    builder: (_) => _TagPickerDialog(
      allTags: allTags,
      selected: selected,
      onCreateTag: onCreateTag,
    ),
  );
  return allTags.where((tag) => selected.contains(tag.id)).toList();
}

class _TagPickerDialog extends StatefulWidget {
  const _TagPickerDialog({
    required this.allTags,
    required this.selected,
    required this.onCreateTag,
  });

  final List<Tag> allTags;
  final Set<int> selected;
  final CreateTagFromPicker? onCreateTag;

  @override
  State<_TagPickerDialog> createState() => _TagPickerDialogState();
}

class _TagPickerDialogState extends State<_TagPickerDialog> {
  final _controller = TextEditingController();
  String _query = '';
  bool _creating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Tag> _childrenOf(int? parentId) => widget.allTags
      .where((tag) => tag.parentTagId == parentId)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<({Tag tag, int depth})> _flatten() {
    final result = <({Tag tag, int depth})>[];
    final visited = <int>{};

    void visit(int? parentId, int depth) {
      for (final tag in _childrenOf(parentId)) {
        if (!visited.add(tag.id)) continue;
        result.add((tag: tag, depth: depth));
        visit(tag.id, depth + 1);
      }
    }

    visit(null, 0);
    for (final tag in widget.allTags) {
      if (visited.add(tag.id)) result.add((tag: tag, depth: 0));
    }
    return result;
  }

  Tag? _exactMatch(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    for (final tag in widget.allTags) {
      if (tag.name.trim().toLowerCase() == value) return tag;
    }
    return null;
  }

  void _toggle(Tag tag) {
    setState(() {
      if (!widget.selected.remove(tag.id)) widget.selected.add(tag.id);
    });
  }

  void _clearQuery() {
    setState(() {
      _query = '';
      _controller.clear();
    });
  }

  Future<void> _quickCreateOrSelect(String raw) async {
    final value = raw.trim();
    if (value.isEmpty || _creating) return;
    final existing = _exactMatch(value);
    if (existing != null) {
      setState(() => widget.selected.add(existing.id));
      _clearQuery();
      return;
    }
    if (widget.onCreateTag == null) return;
    setState(() => _creating = true);
    try {
      final created = await widget.onCreateTag!(value, null);
      if (!mounted || created == null) return;
      setState(() {
        if (!widget.allTags.any((tag) => tag.id == created.id)) {
          widget.allTags.add(created);
        }
        widget.selected.add(created.id);
      });
      _clearQuery();
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _createWithParent() async {
    if (widget.onCreateTag == null) return;
    var name = _query.trim();
    Tag? parent;
    final created = await showDialog<Tag?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
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
                    ...widget.allTags.map(
                      (tag) => DropdownMenuItem<Tag?>(
                        value: tag,
                        child: Text(tag.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setLocalState(() => parent = value),
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
              onPressed: () async {
                final value = name.trim();
                if (value.isEmpty) return;
                final existing = _exactMatch(value);
                if (existing != null) {
                  Navigator.pop(dialogContext, existing);
                  return;
                }
                final valueCreated = await widget.onCreateTag!(value, parent);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, valueCreated);
                }
              },
              child: const Text('作成'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || created == null) return;
    setState(() {
      if (!widget.allTags.any((tag) => tag.id == created.id)) {
        widget.allTags.add(created);
      }
      widget.selected.add(created.id);
    });
    _clearQuery();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = _query.trim().toLowerCase();
    final entries = _flatten()
        .where(
          (entry) =>
              normalized.isEmpty ||
              entry.tag.name.toLowerCase().contains(normalized),
        )
        .toList();
    final exact = _exactMatch(_query);

    return AlertDialog(
      title: const Text('タグDBから選択'),
      content: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          children: [
            if (widget.selected.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.allTags
                      .where((tag) => widget.selected.contains(tag.id))
                      .map(
                        (tag) => InputChip(
                          label: Text(tag.name),
                          onDeleted: () => setState(() => widget.selected.remove(tag.id)),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: _quickCreateOrSelect,
              decoration: InputDecoration(
                hintText: widget.onCreateTag == null
                    ? 'タグを検索'
                    : 'タグを検索・入力して Enter で追加',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _creating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      )
                    : _query.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'クリア',
                            onPressed: _clearQuery,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.onCreateTag != null && _query.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('tag-picker-quick-action'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _quickCreateOrSelect(_query),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(
                      children: [
                        Icon(exact == null ? Icons.add : Icons.check, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            exact == null
                                ? '「${_query.trim()}」を作成  ·  Enter'
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
                    onPressed: _createWithParent,
                    icon: const Icon(Icons.account_tree_outlined, size: 16),
                    label: const Text('親を指定して作成…'),
                  ),
                ),
            ] else if (widget.onCreateTag != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '名前を入力して Enter で作成・選択',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        _query.trim().isEmpty
                            ? 'タグがありません'
                            : widget.onCreateTag == null
                                ? '一致するタグがありません'
                                : 'Enterで「${_query.trim()}」を作成',
                      ),
                    )
                  : ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final checked = widget.selected.contains(entry.tag.id);
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
                              onTap: () => _toggle(entry.tag),
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
                                      _childrenOf(entry.tag.id).isEmpty
                                          ? Icons.sell_outlined
                                          : Icons.folder_outlined,
                                      size: 18,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(entry.tag.name)),
                                    if (checked) const Icon(Icons.check, size: 19),
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
              child: Text('${widget.selected.length} 件選択中'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(widget.selected.clear),
          child: const Text('すべて解除'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

Future<List<Person>?> showPeopleDatabasePicker({
  required BuildContext context,
  required List<Person> people,
  required Iterable<int> initiallySelectedIds,
  CreatePersonFromPicker? onCreatePerson,
}) async {
  final allPeople = <Person>[...people];
  final selected = initiallySelectedIds.toSet();
  await showDialog<void>(
    context: context,
    builder: (_) => _PeoplePickerDialog(
      allPeople: allPeople,
      selected: selected,
      onCreatePerson: onCreatePerson,
    ),
  );
  return allPeople.where((person) => selected.contains(person.id)).toList();
}

class _PeoplePickerDialog extends StatefulWidget {
  const _PeoplePickerDialog({
    required this.allPeople,
    required this.selected,
    required this.onCreatePerson,
  });

  final List<Person> allPeople;
  final Set<int> selected;
  final CreatePersonFromPicker? onCreatePerson;

  @override
  State<_PeoplePickerDialog> createState() => _PeoplePickerDialogState();
}

class _PeoplePickerDialogState extends State<_PeoplePickerDialog> {
  final _controller = TextEditingController();
  String _query = '';
  bool _creating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Person? _exactMatch(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    for (final person in widget.allPeople) {
      if (person.name.trim().toLowerCase() == value) return person;
    }
    return null;
  }

  void _clearQuery() {
    setState(() {
      _query = '';
      _controller.clear();
    });
  }

  void _toggle(Person person) {
    setState(() {
      if (!widget.selected.remove(person.id)) widget.selected.add(person.id);
    });
  }

  Future<void> _quickCreateOrSelect(String raw) async {
    final value = raw.trim();
    if (value.isEmpty || _creating) return;
    final existing = _exactMatch(value);
    if (existing != null) {
      setState(() => widget.selected.add(existing.id));
      _clearQuery();
      return;
    }
    if (widget.onCreatePerson == null) return;
    setState(() => _creating = true);
    try {
      final created = await widget.onCreatePerson!(value, null);
      if (!mounted || created == null) return;
      setState(() {
        if (!widget.allPeople.any((person) => person.id == created.id)) {
          widget.allPeople.add(created);
        }
        widget.selected.add(created.id);
      });
      _clearQuery();
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _createWithDetails() async {
    if (widget.onCreatePerson == null) return;
    var name = _query.trim();
    var note = '';
    final created = await showDialog<Person?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              final value = name.trim();
              if (value.isEmpty) return;
              final existing = _exactMatch(value);
              if (existing != null) {
                Navigator.pop(dialogContext, existing);
                return;
              }
              final valueCreated = await widget.onCreatePerson!(
                value,
                note.trim().isEmpty ? null : note.trim(),
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, valueCreated);
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (!mounted || created == null) return;
    setState(() {
      if (!widget.allPeople.any((person) => person.id == created.id)) {
        widget.allPeople.add(created);
      }
      widget.selected.add(created.id);
    });
    _clearQuery();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normalized = _query.trim().toLowerCase();
    final filtered = widget.allPeople.where((person) {
      if (normalized.isEmpty) return true;
      return person.name.toLowerCase().contains(normalized) ||
          (person.note ?? '').toLowerCase().contains(normalized);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final exact = _exactMatch(_query);

    return AlertDialog(
      title: const Text('人物DBから選択'),
      content: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          children: [
            if (widget.selected.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.allPeople
                      .where((person) => widget.selected.contains(person.id))
                      .map(
                        (person) => InputChip(
                          avatar: const Icon(Icons.person_outline, size: 15),
                          label: Text(person.name),
                          onDeleted: () => setState(() => widget.selected.remove(person.id)),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: _quickCreateOrSelect,
              decoration: InputDecoration(
                hintText: widget.onCreatePerson == null
                    ? '人物を検索'
                    : '人物を検索・名前を入力して Enter で追加',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _creating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      )
                    : _query.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'クリア',
                            onPressed: _clearQuery,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                border: const OutlineInputBorder(),
              ),
            ),
            if (widget.onCreatePerson != null && _query.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('person-picker-quick-action'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _quickCreateOrSelect(_query),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Row(
                      children: [
                        Icon(exact == null ? Icons.add : Icons.check, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            exact == null
                                ? '「${_query.trim()}」を作成  ·  Enter'
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
                    onPressed: _createWithDetails,
                    icon: const Icon(Icons.notes_outlined, size: 16),
                    label: const Text('メモも入力して作成…'),
                  ),
                ),
            ] else if (widget.onCreatePerson != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '名前を入力して Enter で作成・選択',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _query.trim().isEmpty
                            ? '人物がありません'
                            : widget.onCreatePerson == null
                                ? '一致する人物がありません'
                                : 'Enterで「${_query.trim()}」を作成',
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final person = filtered[index];
                        final checked = widget.selected.contains(person.id);
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
                              onTap: () => _toggle(person),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: scheme.surfaceContainerHighest,
                                      child: const Icon(Icons.person_outline, size: 17),
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
                                                fontSize: 11.5,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (checked) const Icon(Icons.check, size: 19),
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
              child: Text('${widget.selected.length} 人選択中'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(widget.selected.clear),
          child: const Text('すべて解除'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
