import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/person_roles.dart';
import 'relation_database_picker.dart';

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
                  const Text('候補', style: TextStyle(fontSize: 12.5, color: Color(0xFF787774))),
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

  Widget _row({
    required String role,
    required List<Person> people,
    required VoidCallback onAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Color(0xFF9B9A97)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    role,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF787774)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? const Text('なし', style: TextStyle(fontSize: 12.5, color: Color(0xFFB0AFAC)))
                : Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: people.map((person) {
                      return ActionChip(
                        avatar: const Icon(Icons.person_outline, size: 14, color: Color(0xFF787774)),
                        label: Text(person.name),
                        onPressed: () => onFilterByPerson?.call(person),
                        backgroundColor: const Color(0xFFF1F1EF),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF565653)),
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
              tooltip: '$roleを人物DBから選択',
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 17, color: Color(0xFF787774)),
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
            ...roles.map(
              (role) => _row(
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
                  foregroundColor: const Color(0xFF787774),
                  textStyle: const TextStyle(fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
