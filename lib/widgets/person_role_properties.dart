import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/person_roles.dart';
import 'bookmark_attachment_section.dart';
import 'relation_database_picker.dart';

const _bookmarkGenres = <String>[
  '動画',
  '漫画',
  '記事',
  '書籍',
  '音楽',
  '映画',
  'アニメ',
  'ゲーム',
  '画像',
  'その他',
];

class PersonRoleProperties extends StatelessWidget {
  const PersonRoleProperties({
    super.key,
    required this.repository,
    required this.bookmark,
    this.onFilterByPerson,
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final ValueChanged<Person>? onFilterByPerson;

  Future<Person?> _createPerson(String name, String? note) async {
    final id = await repository.createPerson(name, note: note);
    final people = await repository.watchPeople().first;
    for (final person in people) {
      if (person.id == id) return person;
    }
    return null;
  }

  Future<void> _selectPeople(
    BuildContext context,
    String role,
    List<PersonRoleAssignment> assignments,
  ) async {
    final allPeople = await repository.watchPeople().first;
    if (!context.mounted) return;
    final current = assignments
        .where((assignment) => assignment.role == role)
        .map((assignment) => assignment.person.id);
    final selected = await showPeopleDatabasePicker(
      context: context,
      people: allPeople,
      initiallySelectedIds: current,
      onCreatePerson: _createPerson,
    );
    if (selected != null) await repository.setPeopleForRole(bookmark, role, selected);
  }

  Future<void> _addRole(
    BuildContext context,
    List<PersonRoleAssignment> assignments,
  ) async {
    final controller = TextEditingController();
    String? selectedRole;
    final existingRoles = assignments.map((assignment) => assignment.role).toSet();
    final suggestions = defaultPersonRoles.where((role) => !existingRoles.contains(role)).toList();

    final role = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('人物プロパティを追加'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (suggestions.isNotEmpty) ...[
                  Text('候補', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: suggestions.map((suggestion) {
                      final selected = selectedRole == suggestion;
                      return ChoiceChip(
                        label: Text(suggestion),
                        selected: selected,
                        onSelected: (_) => setLocalState(() {
                          selectedRole = suggestion;
                          controller.text = suggestion;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: controller,
                  autofocus: suggestions.isEmpty,
                  decoration: const InputDecoration(
                    labelText: '役割名',
                    hintText: '例: 著者、講師、インタビュー対象',
                  ),
                  onChanged: (_) => setLocalState(() => selectedRole = null),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('キャンセル')),
            FilledButton(
              onPressed: () {
                final value = normalizePersonRole(controller.text);
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('次へ'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (role == null || !context.mounted) return;
    await _selectPeople(context, role, assignments);
  }

  Widget _genreRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<String>(
      stream: repository.lifecycleStore.watchGenre(bookmark.id),
      builder: (context, snapshot) {
        final genre = snapshot.data ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 112,
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'ジャンル',
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: genre,
                    isDense: true,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('未設定')),
                      ..._bookmarkGenres.map((value) => DropdownMenuItem(value: value, child: Text(value))),
                    ],
                    onChanged: (value) => repository.lifecycleStore.setGenre(bookmark.id, value ?? ''),
                  ),
                ),
              ),
              const SizedBox(width: 28),
            ],
          ),
        );
      },
    );
  }

  Widget _row({
    required BuildContext context,
    required String role,
    required List<Person> people,
    required VoidCallback onAdd,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    role,
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? Text('なし', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant.withValues(alpha: .55)))
                : Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: people.map((person) {
                      return ActionChip(
                        avatar: Icon(Icons.person_outline, size: 14, color: scheme.onSurfaceVariant),
                        label: Text(person.name),
                        onPressed: () => onFilterByPerson?.call(person),
                        backgroundColor: scheme.surfaceContainerHighest,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        labelStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
          ),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: '$roleを人物DBから選択・新規作成',
              onPressed: onAdd,
              icon: Icon(Icons.add, size: 17, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PersonRoleAssignment>>(
      stream: repository.watchPersonRoles(bookmark),
      builder: (context, snapshot) {
        final assignments = snapshot.data ?? const <PersonRoleAssignment>[];
        final grouped = <String, List<Person>>{};
        for (final assignment in assignments) {
          grouped.putIfAbsent(assignment.role, () => []).add(assignment.person);
        }

        final roles = grouped.keys.toList()
          ..sort((a, b) {
            final aDefault = defaultPersonRoles.indexOf(a);
            final bDefault = defaultPersonRoles.indexOf(b);
            if (aDefault >= 0 && bDefault >= 0) return aDefault.compareTo(bDefault);
            if (aDefault >= 0) return -1;
            if (bDefault >= 0) return 1;
            return a.compareTo(b);
          });
        if (roles.isEmpty) roles.add('出演者');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _genreRow(context),
            ...roles.map(
              (role) => _row(
                context: context,
                role: role,
                people: grouped[role] ?? const <Person>[],
                onAdd: () => _selectPeople(context, role, assignments),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 105, top: 2, bottom: 4),
              child: TextButton.icon(
                onPressed: () => _addRole(context, assignments),
                icon: const Icon(Icons.add, size: 15),
                label: const Text('人物プロパティを追加'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  textStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            BookmarkAttachmentSection(
              repository: repository,
              bookmark: bookmark,
            ),
          ],
        );
      },
    );
  }
}
