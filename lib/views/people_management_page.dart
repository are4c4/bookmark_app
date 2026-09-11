import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../data/app_database.dart';
import '../data/bookmark_repository.dart';
import '../data/database_view_store.dart';
import '../data/generic_database_store.dart';
import '../data/object_store.dart';
import '../data/person_group_object_convergence_service.dart';
import '../data/person_group_object_write_service.dart';
import '../data/person_group_store.dart';
import '../data/person_object_bridge.dart';
import '../data/system_object_store.dart';
import '../database/database_definition.dart';
import '../services/bookmark_presentation_resolver_factory.dart';
import '../services/bookmark_url_resolver.dart';
import '../services/person_profile_image_relation_service.dart';
import '../services/person_profile_image_relation_service_factory.dart';
import '../features/database/presentation/widgets/database_create_tiles.dart';
import '../features/database/presentation/widgets/database_page_toolbar.dart';
import '../features/database/presentation/widgets/database_view_tabs.dart';
import '../features/database/presentation/widgets/resizable_detail_pane.dart';
import '../ui/ui_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/bookmark_resolved_url_text.dart';
import '../widgets/bookmark_reverse_lookup_dialog.dart';
import '../widgets/detail_section.dart';
import '../widgets/inline_rename_text.dart';
import '../widgets/notion_inline_field.dart';
import '../widgets/person_profile_image.dart';

enum PeopleViewType { gallery, list, table }

class PeopleManagementPage extends StatefulWidget {
  const PeopleManagementPage({super.key, required this.repository});
  final BookmarkRepository repository;

  @override
  State<PeopleManagementPage> createState() => _PeopleManagementPageState();
}

class _PeopleManagementPageState extends State<PeopleManagementPage> {
  PeopleViewType _viewType = PeopleViewType.gallery;
  String _query = '';
  int? _selectedPersonId;
  int? _selectedGroupId;
  late final PersonGroupStore _personGroups;
  late final PersonGroupObjectWriteService _personGroupWrites;
  late final PersonGroupObjectConvergenceService _groupMembershipWrites;
  late final DatabaseViewStore _databaseViewStore;
  late final BookmarkUrlResolve _resolveBookmarkUrl;
  late final PersonProfileImageRelationService _profileImages;
  int _profileImageRevision = 0;
  DatabaseViewConfig? _activeDatabaseView;
  int? _activeDatabaseViewId;
  Timer? _viewSaveTimer;

  BookmarkRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    final database = repository.workspaceStore.database;
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjectStore = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final personBridge = PersonObjectBridge(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjectStore,
    );
    _personGroups = PersonGroupStore(database);
    _personGroupWrites = PersonGroupObjectWriteService(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjectStore,
      personBridge: personBridge,
    );
    _groupMembershipWrites = PersonGroupObjectConvergenceService(
      database: database,
      objectStore: objectStore,
      systemObjectStore: systemObjectStore,
      personBridge: personBridge,
    );
    _databaseViewStore = DatabaseViewStore(database);
    _resolveBookmarkUrl =
        BookmarkPresentationResolverFactory.urlFor(repository);
    _profileImages = createPersonProfileImageRelationService(repository);
  }

  @override
  void dispose() {
    _viewSaveTimer?.cancel();
    super.dispose();
  }

  void _applyDatabaseView(DatabaseViewConfig view) {
    final filters = view.filters;
    setState(() {
      _activeDatabaseView = view;
      _activeDatabaseViewId = view.id;
      _query = (filters['query'] as String?) ?? '';
      _selectedGroupId = (filters['groupId'] as num?)?.toInt();
      _viewType = switch (view.layoutType) {
        'list' => PeopleViewType.list,
        'table' => PeopleViewType.table,
        _ => PeopleViewType.gallery,
      };
    });
  }

  void _markDatabaseViewChanged() {
    final active = _activeDatabaseView;
    if (active == null) return;
    _viewSaveTimer?.cancel();
    _viewSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || _activeDatabaseViewId != active.id) return;
      final next = active.copyWith(
        layoutType: switch (_viewType) {
          PeopleViewType.list => 'list',
          PeopleViewType.table => 'table',
          _ => 'gallery',
        },
        filters: {'query': _query, 'groupId': _selectedGroupId},
      );
      await _databaseViewStore.updateView(next);
      if (mounted && _activeDatabaseViewId == active.id) _activeDatabaseView = next;
    });
  }

  Widget _databaseViewTabs() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 10, 0),
        child: DatabaseViewTabs(
          store: _databaseViewStore,
          definition: BuiltInDatabases.people,
          workspaceId: repository.workspaceId,
          activeViewId: _activeDatabaseViewId,
          onSelected: _applyDatabaseView,
        ),
      );

  List<BookmarkItem> _bookmarksFor(
    Person person,
    List<BookmarkItem> bookmarks,
  ) => bookmarks
      .where(
        (bookmark) =>
            bookmark.people.any((candidate) => candidate.id == person.id),
      )
      .toList();

  Future<void> _renamePerson(Person person, String name) =>
      repository.updatePerson(person, name, person.note);

  Future<void> _saveNote(Person person, String note) =>
      repository.updatePerson(person, person.name, note);

  Future<void> _createPersonInline(String name) async {
    final value = name.trim();
    if (value.isEmpty) return;
    final existing = await repository.watchPeople().first;
    final duplicate = existing.where(
      (person) => person.name.trim().toLowerCase() == value.toLowerCase(),
    );
    if (duplicate.isNotEmpty) {
      if (mounted) setState(() => _selectedPersonId = duplicate.first.id);
      return;
    }
    final id = await repository.createPerson(value);
    if (mounted) setState(() => _selectedPersonId = id);
  }

  Future<void> _delete(Person person) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('人物を削除しますか？'),
        content: Text('「${person.name}」を人物DBから削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repository.deletePerson(person);
      if (mounted && _selectedPersonId == person.id) {
        setState(() => _selectedPersonId = null);
      }
    }
  }

  void _showGroupMutationFailure() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('人物グループを更新できませんでした。状態を確認してもう一度お試しください。')),
      );
  }

  Future<PersonGroupObjectWriteResult?> _createGroup(String name) async {
    try {
      return await _personGroupWrites.create(
        workspaceId: repository.workspaceId,
        name: name,
      );
    } catch (_) {
      _showGroupMutationFailure();
      return null;
    }
  }

  Future<bool> _renameGroup(int groupId, String name) async {
    try {
      await _personGroupWrites.rename(
        workspaceId: repository.workspaceId,
        legacyGroupId: groupId,
        name: name,
      );
      return true;
    } catch (_) {
      _showGroupMutationFailure();
      return false;
    }
  }

  Future<bool> _deleteGroup(int groupId) async {
    try {
      await _personGroupWrites.delete(
        workspaceId: repository.workspaceId,
        legacyGroupId: groupId,
      );
      return true;
    } catch (_) {
      _showGroupMutationFailure();
      return false;
    }
  }

  Future<bool> _setGroupsForPerson(int personId, Iterable<int> groupIds) async {
    try {
      await _groupMembershipWrites.setGroupsForLegacyPerson(
        workspaceId: repository.workspaceId,
        legacyPersonId: personId,
        legacyGroupIds: groupIds,
      );
      return true;
    } catch (_) {
      _showGroupMutationFailure();
      return false;
    }
  }

  Future<void> _showGroupManager() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('人物グループ'),
          content: SizedBox(
            width: 430,
            height: 430,
            child: Column(
              children: [
                SafeQuickCreateField(
                  prefixIcon: Icons.add,
                  hintText: 'グループ名を入力して Enter',
                  onSubmitted: (value) async {
                    final created = await _createGroup(value);
                    if (created == null) return;
                    if (dialogContext.mounted) setLocalState(() {});
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<PersonGroupInfo>>(
                    future: _personGroups.listGroups(),
                    builder: (context, snapshot) {
                      final groups = snapshot.data ?? const <PersonGroupInfo>[];
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (groups.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.group_work_outlined,
                          title: 'グループはまだありません',
                          message: '例：サカナクション、研究室、会社など',
                        );
                      }
                      return ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return ListTile(
                            leading: const Icon(Icons.group_outlined),
                            title: InlineRenameText(
                              value: group.name,
                              onSubmitted: (value) async {
                                if (!await _renameGroup(group.id, value)) {
                                  return;
                                }
                                if (dialogContext.mounted) setLocalState(() {});
                                if (mounted) setState(() {});
                              },
                            ),
                            trailing: IconButton(
                              tooltip: '削除',
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () async {
                                if (!await _deleteGroup(group.id)) {
                                  return;
                                }
                                if (_selectedGroupId == group.id && mounted) {
                                  setState(() => _selectedGroupId = null);
                                }
                                if (dialogContext.mounted) setLocalState(() {});
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGroupsForPerson(Person person) async {
    final groups = await _personGroups.listGroups();
    final current = (await _personGroups.groupsForPerson(person.id))
        .map((group) => group.id)
        .toSet();
    if (!mounted) return;
    final all = <PersonGroupInfo>[...groups];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('${person.name} の所属'),
          content: SizedBox(
            width: 430,
            height: 440,
            child: Column(
              children: [
                SafeQuickCreateField(
                  prefixIcon: Icons.add,
                  hintText: 'グループを作成して追加',
                  onSubmitted: (value) async {
                    final created = await _createGroup(value);
                    if (created == null) return;
                    final refreshed = await _personGroups.listGroups();
                    final next = <int>{...current, created.legacyGroupId};
                    final committed = await _setGroupsForPerson(person.id, next);
                    all
                      ..clear()
                      ..addAll(refreshed);
                    if (committed) {
                      current
                        ..clear()
                        ..addAll(next);
                    }
                    if (dialogContext.mounted) setLocalState(() {});
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: all.length,
                    itemBuilder: (context, index) {
                      final group = all[index];
                      final selected = current.contains(group.id);
                      final scheme = Theme.of(context).colorScheme;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Material(
                          color: selected
                              ? scheme.secondaryContainer.withValues(alpha: .45)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(5),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(5),
                            onTap: () async {
                              final next = <int>{...current};
                              if (selected) {
                                next.remove(group.id);
                              } else {
                                next.add(group.id);
                              }
                              if (!await _setGroupsForPerson(person.id, next)) {
                                return;
                              }
                              current
                                ..clear()
                                ..addAll(next);
                              if (dialogContext.mounted) setLocalState(() {});
                              if (mounted) setState(() {});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.group_outlined, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(group.name)),
                                  if (selected)
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _galleryImage(Person person) => PersonProfileImageMedia(
        service: _profileImages,
        workspaceId: repository.workspaceId,
        personId: person.id,
        revision: _profileImageRevision,
        width: double.infinity,
        height: 180,
      );

  Widget _avatar(Person person) => PersonProfileImageMedia(
        service: _profileImages,
        workspaceId: repository.workspaceId,
        personId: person.id,
        revision: _profileImageRevision,
        width: 44,
        height: 44,
        clipOval: true,
        placeholderBuilder: (context) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: const Center(child: Icon(Icons.person_outline, size: 22)),
        ),
      );

  void _showRelated(Person person, List<BookmarkItem> bookmarks) {
    final related = _bookmarksFor(person, bookmarks);
    showBookmarkReverseLookupDialog(
      context: context,
      repository: repository,
      title: '${person.name} のブックマーク（${related.length}件）',
      bookmarks: repository.watchBookmarksForPerson(person),
    );
  }

  Widget _menu(Person person, List<BookmarkItem> bookmarks) =>
      PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'detail') setState(() => _selectedPersonId = person.id);
          if (value == 'bookmarks') _showRelated(person, bookmarks);
          if (value == 'groups') _editGroupsForPerson(person);
          if (value == 'delete') _delete(person);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'detail', child: Text('詳細を表示')),
          PopupMenuItem(value: 'bookmarks', child: Text('関連ブックマークを見る')),
          PopupMenuItem(value: 'groups', child: Text('所属グループを編集')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Text('削除')),
        ],
      );

  Widget _personCard(
    Person person,
    List<BookmarkItem> bookmarks,
  ) {
    final related = _bookmarksFor(person, bookmarks);
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedPersonId == person.id;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(UiTokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedPersonId = person.id),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(UiTokens.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _galleryImage(person),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InlineRenameText(
                            value: person.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            onSubmitted: (value) =>
                                _renamePerson(person, value),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${related.length}件のブックマーク',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _menu(person, bookmarks),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gallery(
    List<Person> people,
    List<BookmarkItem> bookmarks,
  ) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width >= 1250
              ? 5
              : width >= 960
                  ? 4
                  : width >= 680
                      ? 3
                      : width >= 430
                          ? 2
                          : 1;
          return MasonryGridView.count(
            padding: const EdgeInsets.fromLTRB(18, UiTokens.space16, 18, 100),
            crossAxisCount: columns,
            crossAxisSpacing: UiTokens.space12,
            mainAxisSpacing: UiTokens.space12,
            itemCount: people.length + 1,
            itemBuilder: (context, index) {
              if (index == people.length) {
                return DatabaseCreateCard(
                  label: '新しい人物',
                  icon: Icons.person_add_alt_1_outlined,
                  hintText: '人物名を入力して Enter',
                  onCreate: _createPersonInline,
                );
              }
              return _personCard(people[index], bookmarks);
            },
          );
        },
      );

  Widget _list(
    List<Person> people,
    List<BookmarkItem> bookmarks,
  ) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, UiTokens.space12, 18, 100),
        itemCount: people.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == people.length) {
            return DatabaseCreateRow(
              label: '新しい人物',
              icon: Icons.person_add_alt_1_outlined,
              hintText: '人物名を入力して Enter',
              onCreate: _createPersonInline,
            );
          }
          final person = people[index];
          final related = _bookmarksFor(person, bookmarks);
          return ListTile(
            selected: _selectedPersonId == person.id,
            leading: _avatar(person),
            title: InlineRenameText(
              value: person.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              onSubmitted: (value) => _renamePerson(person, value),
            ),
            subtitle: Text(
              [
                '${related.length}件のブックマーク',
                if (person.note?.trim().isNotEmpty == true) person.note!,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _menu(person, bookmarks),
            onTap: () => setState(() => _selectedPersonId = person.id),
          );
        },
      );

  Widget _table(
    List<Person> people,
    List<BookmarkItem> bookmarks,
  ) => Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, UiTokens.space12, 18, 8),
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('人物')),
                  DataColumn(label: Text('メモ')),
                  DataColumn(label: Text('ブックマーク')),
                  DataColumn(label: Text('')),
                ],
                rows: people.map((person) {
                  final related = _bookmarksFor(person, bookmarks);
                  return DataRow(
                    selected: _selectedPersonId == person.id,
                    onSelectChanged: (_) =>
                        setState(() => _selectedPersonId = person.id),
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            _avatar(person),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 180,
                              child: InlineRenameText(
                                value: person.name,
                                onSubmitted: (value) =>
                                    _renamePerson(person, value),
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 280,
                          child: Text(
                            person.note ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text('${related.length}件')),
                      DataCell(_menu(person, bookmarks)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          DatabaseCreateRow(
            label: '新しい人物',
            icon: Icons.person_add_alt_1_outlined,
            hintText: '人物名を入力して Enter',
            onCreate: _createPersonInline,
          ),
          const SizedBox(height: 8),
        ],
      );

  Widget _profileImageEditor(Person person) => PersonProfileImageEditor(
        service: _profileImages,
        workspaceId: repository.workspaceId,
        person: person,
        revision: _profileImageRevision,
        onChanged: () {
          if (!mounted) return;
          setState(() => _profileImageRevision++);
        },
      );

  Widget _groupsSection(Person person) => FutureBuilder<List<PersonGroupInfo>>(
        future: _personGroups.groupsForPerson(person.id),
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const <PersonGroupInfo>[];
          final scheme = Theme.of(context).colorScheme;
          return InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () => _editGroupsForPerson(person),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...groups.map(
                    (group) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.group_outlined, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            group.name,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (groups.isEmpty)
                    Text(
                      'グループを追加…',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant.withValues(alpha: .65),
                      ),
                    )
                  else
                    Icon(
                      Icons.add,
                      size: 17,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          );
        },
      );

  Widget _detail(
    Person person,
    List<BookmarkItem> bookmarks,
  ) {
    final related = _bookmarksFor(person, bookmarks);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          SizedBox(
            height: UiTokens.toolbarHeight,
            child: Row(
              children: [
                const SizedBox(width: UiTokens.space16),
                const Text(
                  '人物の詳細',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'その他',
                  onSelected: (value) {
                    if (value == 'delete') _delete(person);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('人物を削除')),
                  ],
                ),
                IconButton(
                  tooltip: '閉じる',
                  onPressed: () => setState(() => _selectedPersonId = null),
                  icon: const Icon(Icons.close, size: 19),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              children: [
                _profileImageEditor(person),
                const SizedBox(height: 10),
                InlineRenameText(
                  value: person.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                  onSubmitted: (value) => _renamePerson(person, value),
                ),
                const SizedBox(height: 4),
                Text(
                  '${related.length}件の関連ブックマーク',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: UiTokens.space16),
                DetailSection(
                  title: '基本情報',
                  icon: Icons.person_outline,
                  topDivider: false,
                  child: NotionInlineField(
                    value: person.note ?? '',
                    hintText: 'メモを追加…',
                    maxLines: null,
                    style: const TextStyle(fontSize: 13.5, height: 1.55),
                    onSaved: (value) => _saveNote(person, value),
                  ),
                ),
                DetailSection(
                  title: '所属',
                  icon: Icons.group_outlined,
                  child: _groupsSection(person),
                ),
                DetailSection(
                  title: 'Relation',
                  icon: Icons.link_outlined,
                  trailing: related.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => _showRelated(person, bookmarks),
                          child: const Text('すべて見る'),
                        ),
                  child: related.isEmpty
                      ? Text(
                          '関連ブックマークはありません',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        )
                      : Column(
                          children: related
                              .take(8)
                              .map(
                                (bookmark) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.bookmark_outline,
                                    size: UiTokens.iconNormal,
                                  ),
                                  title: Text(
                                    bookmark.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: BookmarkResolvedUrlText(
                                    bookmark: bookmark,
                                    resolveUrl: _resolveBookmarkUrl,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewSwitcher() => SegmentedButton<PeopleViewType>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: PeopleViewType.gallery,
            icon: Icon(Icons.grid_view, size: 17),
          ),
          ButtonSegment(
            value: PeopleViewType.list,
            icon: Icon(Icons.view_list, size: 17),
          ),
          ButtonSegment(
            value: PeopleViewType.table,
            icon: Icon(Icons.table_rows, size: 17),
          ),
        ],
        selected: {_viewType},
        onSelectionChanged: (value) => setState(() {
          _viewType = value.first;
          _markDatabaseViewChanged();
        }),
      );

  Widget _groupFilter() => FutureBuilder<List<PersonGroupInfo>>(
        future: _personGroups.listGroups(),
        builder: (context, snapshot) {
          final groups = snapshot.data ?? const <PersonGroupInfo>[];
          final current = groups
              .where((group) => group.id == _selectedGroupId)
              .firstOrNull;
          return PopupMenuButton<int>(
            tooltip: '人物グループ',
            onSelected: (id) {
              if (id == -2) {
                _showGroupManager();
                return;
              }
              setState(() {
                _selectedGroupId = id < 0 ? null : id;
                _markDatabaseViewChanged();
              });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: -1, child: Text('すべての人物')),
              ...groups.map(
                (group) => PopupMenuItem(
                  value: group.id,
                  child: Text(group.name),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: -2, child: Text('グループを管理…')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_outlined, size: 17),
                  const SizedBox(width: 5),
                  Text(current?.name ?? 'グループ'),
                ],
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _databaseViewTabs(),
          DatabasePageToolbar(
            title: '人物',
            searchHint: '人物を検索',
            searchValue: _query,
            onSearchChanged: (value) => setState(() {
              _query = value;
              _markDatabaseViewChanged();
            }),
            leadingActions: [_groupFilter()],
            viewSwitcher: _viewSwitcher(),
          ),
          Expanded(
            child: StreamBuilder<List<Person>>(
              stream: repository.watchPeople(),
              builder: (context, peopleSnapshot) {
                if (!peopleSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StreamBuilder<List<BookmarkItem>>(
                  stream: repository.watchAll(),
                  builder: (context, bookmarkSnapshot) {
                    final bookmarks =
                        bookmarkSnapshot.data ?? const <BookmarkItem>[];
                    final all = peopleSnapshot.data!;
                    return FutureBuilder<Set<int>>(
                      future: _selectedGroupId == null
                          ? Future.value(all.map((person) => person.id).toSet())
                          : _personGroups.memberIds(_selectedGroupId!),
                      builder: (context, groupSnapshot) {
                        final allowedIds = groupSnapshot.data ?? <int>{};
                        final q = _query.trim().toLowerCase();
                        final people = all.where((person) {
                          if (_selectedGroupId != null &&
                              !allowedIds.contains(person.id)) {
                            return false;
                          }
                          return q.isEmpty ||
                              '${person.name} ${person.note ?? ''}'
                                  .toLowerCase()
                                  .contains(q);
                        }).toList();
                        final selected = all
                            .where((person) => person.id == _selectedPersonId)
                            .firstOrNull;

                        return Row(
                          children: [
                            Expanded(
                              child: people.isEmpty && q.isNotEmpty
                                  ? const AppEmptyState(
                                      icon: Icons.search_off_outlined,
                                      title: '条件に一致する人物がいません',
                                    )
                                  : switch (_viewType) {
                                      PeopleViewType.gallery =>
                                        _gallery(people, bookmarks),
                                      PeopleViewType.list =>
                                        _list(people, bookmarks),
                                      PeopleViewType.table =>
                                        _table(people, bookmarks),
                                    },
                            ),
                            if (selected != null)
                              ResizableDetailPane(
                                storageKey: 'people-detail-pane',
                                initialWidth: 400,
                                child: _detail(selected, bookmarks),
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
