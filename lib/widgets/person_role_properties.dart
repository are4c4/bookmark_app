import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/person_roles.dart';
import 'bookmark_attachment_section.dart';
import 'detail_property_row.dart';
import 'relation_database_picker.dart';

const _bookmarkGenres = <String>[
  '動画', '漫画', '記事', '書籍', '音楽', '映画', 'アニメ', 'ゲーム', '画像', 'その他',
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
    return people.where((person) => person.id == id).firstOrNull;
  }

  Future<void> _selectPeople(
    BuildContext context,
    String role,
    List<PersonRoleAssignment> assignments,
  ) async {
    final allPeople = await repository.watchPeople().first;
    if (!context.mounted) return;
    final selected = await showPeopleDatabasePicker(
      context: context,
      people: allPeople,
      initiallySelectedIds: assignments
          .where((assignment) => assignment.role == role)
          .map((assignment) => assignment.person.id),
      onCreatePerson: _createPerson,
    );
    if (selected != null) {
      await repository.setPeopleForRole(bookmark, role, selected);
    }
  }

  Future<void> _addRole(
    BuildContext context,
    List<PersonRoleAssignment> assignments,
  ) async {
    final existingRoles = assignments.map((assignment) => assignment.role).toSet();
    final suggestions = defaultPersonRoles
        .where((role) => !existingRoles.contains(role))
        .toList();
    String typedRole = '';
    String? selectedRole;

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
                  Text(
                    '候補',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: suggestions
                        .map(
                          (suggestion) => ChoiceChip(
                            label: Text(suggestion),
                            selected: selectedRole == suggestion,
                            onSelected: (_) => setLocalState(() {
                              selectedRole = suggestion;
                              typedRole = '';
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  autofocus: suggestions.isEmpty,
                  decoration: InputDecoration(
                    labelText: '役割名',
                    hintText: selectedRole ?? '例: 著者、講師、監督',
                  ),
                  onChanged: (value) => setLocalState(() {
                    typedRole = value;
                    if (value.trim().isNotEmpty) selectedRole = null;
                  }),
                  onFieldSubmitted: (_) {
                    final value = normalizePersonRole(
                      selectedRole ?? typedRole,
                    );
                    if (value.isNotEmpty) Navigator.pop(dialogContext, value);
                  },
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
              onPressed: () {
                final value = normalizePersonRole(selectedRole ?? typedRole);
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('次へ'),
            ),
          ],
        ),
      ),
    );
    if (role == null || !context.mounted) return;
    await _selectPeople(context, role, assignments);
  }

  Future<void> _addPersonToDroppedBookmark(
    BuildContext context,
    int bookmarkId,
    String role,
    Person person,
  ) async {
    final items = await repository.watchAll().first;
    final dropped = items.where((item) => item.id == bookmarkId).firstOrNull;
    if (dropped == null) return;

    final assignments = await repository.watchPersonRoles(dropped).first;
    final people = assignments
        .where((assignment) => assignment.role == role)
        .map((assignment) => assignment.person)
        .toList();
    final byId = <int, Person>{for (final value in people) value.id: value};
    byId[person.id] = person;
    await repository.setPeopleForRole(dropped, role, byId.values);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text('「${dropped.title}」に $role: ${person.name} を追加しました'),
        ),
      );
    }
  }

  Widget _genreRow(BuildContext context) => StreamBuilder<String>(
        stream: repository.lifecycleStore.watchGenre(bookmark.id),
        builder: (context, snapshot) {
          final genre = snapshot.data ?? '';
          final items = <String, String>{
            '': '未設定',
            for (final value in _bookmarkGenres) value: value,
          };
          return DetailPropertyRow(
            icon: Icons.category_outlined,
            label: 'ジャンル',
            child: DetailSelectField<String>(
              value: genre,
              items: items,
              empty: genre.isEmpty,
              onSelected: (value) =>
                  repository.lifecycleStore.setGenre(bookmark.id, value),
            ),
          );
        },
      );

  Widget _personChip(BuildContext context, String role, Person person) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != bookmark.id,
      onAcceptWithDetails: (details) => _addPersonToDroppedBookmark(
        context,
        details.data,
        role,
        person,
      ),
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: hovering
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
          ),
          child: ActionChip(
            avatar: Icon(
              Icons.person_outline,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            label: Text(person.name),
            onPressed: () => onFilterByPerson?.call(person),
            backgroundColor: hovering
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            labelStyle: TextStyle(
              fontSize: 12,
              color: hovering
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }

  Widget _personRow(
    BuildContext context,
    String role,
    List<Person> people,
    VoidCallback onAdd,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return DetailPropertyRow(
      icon: Icons.person_outline,
      label: role,
      onAdd: onAdd,
      onTapValue: onAdd,
      addTooltip: '$roleを人物DBから選択・新規作成',
      child: people.isEmpty
          ? Text(
              'なし',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onSurfaceVariant.withValues(alpha: .55),
              ),
            )
          : Wrap(
              spacing: 5,
              runSpacing: 5,
              children: people
                  .map((person) => _personChip(context, role, person))
                  .toList(),
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
            final ai = defaultPersonRoles.indexOf(a);
            final bi = defaultPersonRoles.indexOf(b);
            if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
            if (ai >= 0) return -1;
            if (bi >= 0) return 1;
            return a.compareTo(b);
          });
        if (roles.isEmpty) roles.add('出演者');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _genreRow(context),
            ...roles.map(
              (role) => _personRow(
                context,
                role,
                grouped[role] ?? const <Person>[],
                () => _selectPeople(context, role, assignments),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(112, 2, 0, 4),
              child: TextButton.icon(
                onPressed: () => _addRole(context, assignments),
                icon: const Icon(Icons.add, size: 15),
                label: const Text('人物プロパティを追加'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                  textStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 2),
            BookmarkAttachmentSection(repository: repository, bookmark: bookmark),
          ],
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
