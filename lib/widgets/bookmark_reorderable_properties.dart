import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/person_roles.dart';
import '../features/database/presentation/widgets/property_add_popover.dart';
import '../features/object/presentation/widgets/property_drag_handle.dart';
import 'bookmark_attachment_section.dart';
import 'detail_property_row.dart';
import 'relation_database_picker.dart';

const _statusLabels = <String, String>{
  'unread': '未読',
  'later': '後で見る',
  'in_progress': '閲覧中 / 視聴中',
  'done': '完了 / 視聴済み',
  'archived': 'アーカイブ',
};

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

class BookmarkReorderableProperties extends StatelessWidget {
  const BookmarkReorderableProperties({
    super.key,
    required this.repository,
    required this.bookmark,
    required this.propertyOrder,
    required this.onPropertyOrderChanged,
    this.onFilterByTag,
    this.onFilterByPerson,
  });

  final BookmarkRepository repository;
  final BookmarkItem bookmark;
  final List<String> propertyOrder;
  final ValueChanged<List<String>> onPropertyOrderChanged;
  final ValueChanged<Tag>? onFilterByTag;
  final ValueChanged<Person>? onFilterByPerson;

  Future<Tag?> _createTag(String name, Tag? parent) async {
    final id = await repository.createTag(name, parent: parent);
    final tags = await repository.watchTags().first;
    return tags.where((tag) => tag.id == id).firstOrNull;
  }

  Future<Person?> _createPerson(String name, String? note) async {
    final id = await repository.createPerson(name, note: note);
    final people = await repository.watchPeople().first;
    return people.where((person) => person.id == id).firstOrNull;
  }

  Future<void> _selectTags(BuildContext context) async {
    final tags = await repository.watchTags().first;
    if (!context.mounted) return;
    final selected = await showTagDatabasePicker(
      context: context,
      tags: tags,
      initiallySelectedIds: bookmark.tags.map((tag) => tag.id),
      onCreateTag: _createTag,
    );
    if (selected != null) {
      await repository.setBookmarkTagsFromDatabase(bookmark, selected);
    }
  }

  Future<void> _selectCollections(BuildContext context) async {
    final all = await repository.watchCollections().first;
    final selectedIds = bookmark.collections.map((item) => item.id).toSet();
    if (!context.mounted) return;
    final result = await showDialog<List<CollectionRecord>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('コレクションを選択'),
          content: SizedBox(
            width: 420,
            height: 340,
            child: all.isEmpty
                ? const Center(child: Text('コレクションがありません'))
                : ListView(
                    children: all
                        .map(
                          (collection) => CheckboxListTile(
                            value: selectedIds.contains(collection.id),
                            title: Text(collection.name),
                            onChanged: (selected) => setLocalState(() {
                              if (selected == true) {
                                selectedIds.add(collection.id);
                              } else {
                                selectedIds.remove(collection.id);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                all.where((item) => selectedIds.contains(item.id)).toList(),
              ),
              child: const Text('適用'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await repository.setBookmarkCollections(bookmark, result);
  }

  Future<void> _selectPeople(
    BuildContext context,
    String role,
    List<PersonRoleAssignment> assignments,
  ) async {
    final people = await repository.watchPeople().first;
    if (!context.mounted) return;
    final selected = await showPeopleDatabasePicker(
      context: context,
      people: people,
      initiallySelectedIds: assignments
          .where((assignment) => assignment.role == role)
          .map((assignment) => assignment.person.id),
      onCreatePerson: _createPerson,
    );
    if (selected != null) {
      await repository.setPeopleForRole(bookmark, role, selected);
      final token = 'role:$role';
      if (!propertyOrder.contains(token)) {
        onPropertyOrderChanged([...propertyOrder, token]);
      }
    }
  }

  Future<void> _addRoleProperty(
    BuildContext context,
    String role,
    List<PersonRoleAssignment> assignments,
  ) async {
    final normalizedRole = normalizePersonRole(role);
    if (normalizedRole.isEmpty) return;
    final token = 'role:$normalizedRole';
    if (!propertyOrder.contains(token)) {
      onPropertyOrderChanged([...propertyOrder, token]);
    }
    if (!context.mounted) return;
    await _selectPeople(context, normalizedRole, assignments);
  }

  Widget _roleAddPopover(
    BuildContext context,
    List<PersonRoleAssignment> assignments,
  ) {
    final visibleRoles = <String>{
      ...assignments.map((assignment) => assignment.role),
      for (final token in propertyOrder)
        if (token.startsWith('role:')) token.substring('role:'.length),
    };
    final hiddenRoles = <PropertyAddCandidate>[
      for (var index = 0; index < defaultPersonRoles.length; index++)
        if (!visibleRoles.contains(defaultPersonRoles[index]))
          PropertyAddCandidate(
            id: index,
            name: defaultPersonRoles[index],
            type: '人物',
          ),
    ];

    return PropertyAddPopover(
      buttonKey: const ValueKey('bookmark-reorderable-person-role-add'),
      buttonLabel: '人物プロパティを追加',
      tooltip: '人物プロパティを追加',
      hiddenProperties: hiddenRoles,
      propertyTypes: const [
        PropertyAddTypeOption(
          key: 'personRole',
          label: '人物',
          icon: Icons.person_outline,
        ),
      ],
      onRevealExisting: (candidate) =>
          _addRoleProperty(context, candidate.name, assignments),
      onCreateNew: (request) =>
          _addRoleProperty(context, request.name, assignments),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'まだ開いていません';
    final local = value.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }

  Widget _rating(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final value = index + 1;
        return InkWell(
          borderRadius: BorderRadius.circular(3),
          onTap: () => repository.setRating(bookmark, bookmark.rating == value ? 0 : value),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Icon(
              value <= bookmark.rating ? Icons.star : Icons.star_border,
              size: 18,
              color: value <= bookmark.rating ? const Color(0xFFB8860B) : scheme.onSurfaceVariant,
            ),
          ),
        );
      }),
    );
  }

  Widget _tagValue(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (bookmark.tags.isEmpty) {
      return Text('なし', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant.withValues(alpha: .55)));
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: bookmark.tags
          .map(
            (tag) => ActionChip(
              label: Text(tag.name),
              onPressed: () => onFilterByTag?.call(tag),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              backgroundColor: scheme.surfaceContainerHighest,
              labelStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          )
          .toList(),
    );
  }

  Widget _collectionsValue(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (bookmark.collections.isEmpty) {
      return Text('なし', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant.withValues(alpha: .55)));
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: bookmark.collections
          .map(
            (collection) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(collection.name, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
    );
  }

  Widget _personValue(BuildContext context, String role, List<Person> people) {
    final scheme = Theme.of(context).colorScheme;
    if (people.isEmpty) {
      return Text('なし', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant.withValues(alpha: .55)));
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: people
          .map(
            (person) => ActionChip(
              avatar: const Icon(Icons.person_outline, size: 14),
              label: Text(person.name),
              onPressed: () => onFilterByPerson?.call(person),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          )
          .toList(),
    );
  }

  bool _isDetailToken(String token, Set<String> roleTokens) =>
      const {'status', 'rating', 'tags', 'genre', 'collections', 'history'}.contains(token) ||
      roleTokens.contains(token);

  List<String> _mergeDetailOrder(List<String> reordered, Set<String> roleTokens) {
    final detailTokens = <String>{...reordered};
    final result = <String>[];
    var detailIndex = 0;
    for (final token in propertyOrder) {
      if (_isDetailToken(token, roleTokens) || detailTokens.contains(token)) {
        if (detailIndex < reordered.length) result.add(reordered[detailIndex++]);
      } else {
        result.add(token);
      }
    }
    while (detailIndex < reordered.length) {
      result.add(reordered[detailIndex++]);
    }
    return result.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PersonRoleAssignment>>(
      stream: repository.watchPersonRoles(bookmark),
      builder: (context, roleSnapshot) {
        final assignments = roleSnapshot.data ?? const <PersonRoleAssignment>[];
        final grouped = <String, List<Person>>{};
        for (final assignment in assignments) {
          grouped.putIfAbsent(assignment.role, () => <Person>[]).add(assignment.person);
        }
        final roles = grouped.keys.toList();
        if (roles.isEmpty) roles.add('出演者');
        for (final role in defaultPersonRoles) {
          final token = 'role:$role';
          if (propertyOrder.contains(token) && !roles.contains(role)) roles.add(role);
        }
        final roleTokens = roles.map((role) => 'role:$role').toSet();
        final available = <String>{
          'status',
          'rating',
          'tags',
          'genre',
          ...roleTokens,
          'collections',
          'history',
        };
        final ordered = <String>[];
        for (final token in propertyOrder) {
          if (available.contains(token) && !ordered.contains(token)) ordered.add(token);
        }
        for (final token in available) {
          if (!ordered.contains(token)) ordered.add(token);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: ordered.length,
              onReorderItem: (oldIndex, newIndex) {
                final next = [...ordered];
                final moved = next.removeAt(oldIndex);
                next.insert(newIndex, moved);
                onPropertyOrderChanged(_mergeDetailOrder(next, roleTokens));
              },
              itemBuilder: (context, index) {
                final token = ordered[index];
                final dragHandle = ReorderableDragStartListener(
                  index: index,
                  child: const PropertyDragHandle(),
                );
                Widget row;
                if (token == 'status') {
                  row = DetailPropertyRow(
                    icon: Icons.flag_outlined,
                    label: 'ステータス',
                    dragHandle: dragHandle,
                    child: DetailSelectField<String>(
                      value: bookmark.status,
                      items: _statusLabels,
                      onSelected: (value) => repository.setStatus(bookmark, value),
                    ),
                  );
                } else if (token == 'rating') {
                  row = DetailPropertyRow(
                    icon: Icons.star_outline,
                    label: '評価',
                    dragHandle: dragHandle,
                    child: _rating(context),
                  );
                } else if (token == 'tags') {
                  row = DetailPropertyRow(
                    icon: Icons.sell_outlined,
                    label: 'タグ',
                    dragHandle: dragHandle,
                    onAdd: () => _selectTags(context),
                    onTapValue: () => _selectTags(context),
                    addTooltip: 'タグDBから選択・新規作成',
                    child: _tagValue(context),
                  );
                } else if (token == 'genre') {
                  row = StreamBuilder<String>(
                    stream: repository.lifecycleStore.watchGenre(bookmark.id),
                    builder: (context, snapshot) {
                      final genre = snapshot.data ?? '';
                      return DetailPropertyRow(
                        icon: Icons.category_outlined,
                        label: 'ジャンル',
                        dragHandle: dragHandle,
                        child: DetailSelectField<String>(
                          value: genre,
                          items: {'': '未設定', for (final value in _bookmarkGenres) value: value},
                          empty: genre.isEmpty,
                          onSelected: (value) => repository.lifecycleStore.setGenre(bookmark.id, value),
                        ),
                      );
                    },
                  );
                } else if (token == 'collections') {
                  row = DetailPropertyRow(
                    icon: Icons.collections_bookmark_outlined,
                    label: 'コレクション',
                    dragHandle: dragHandle,
                    onAdd: () => _selectCollections(context),
                    onTapValue: () => _selectCollections(context),
                    addTooltip: 'コレクションを選択',
                    child: _collectionsValue(context),
                  );
                } else if (token == 'history') {
                  row = DetailPropertyRow(
                    icon: Icons.history,
                    label: '履歴',
                    dragHandle: dragHandle,
                    child: Text(
                      '${bookmark.openCount}回 · ${_formatDateTime(bookmark.lastOpenedAt)}',
                      style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  );
                } else {
                  final role = token.substring('role:'.length);
                  final people = grouped[role] ?? const <Person>[];
                  row = DetailPropertyRow(
                    icon: Icons.person_outline,
                    label: role,
                    dragHandle: dragHandle,
                    onAdd: () => _selectPeople(context, role, assignments),
                    onTapValue: () => _selectPeople(context, role, assignments),
                    addTooltip: '$roleを人物DBから選択・新規作成',
                    child: _personValue(context, role, people),
                  );
                }
                return KeyedSubtree(
                  key: ValueKey(token),
                  child: row,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(112, 2, 0, 4),
              child: _roleAddPopover(context, assignments),
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