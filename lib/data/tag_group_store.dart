import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'app_database.dart';

class TagGroupInfo {
  const TagGroupInfo({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final int sortOrder;
}

class TagUsageStats {
  const TagUsageStats({
    required this.directCount,
    required this.aggregateCount,
  });

  final int directCount;
  final int aggregateCount;
}

class TagTreeExpansionState {
  const TagTreeExpansionState({
    this.tagIds = const {},
    this.groupIds = const {},
    this.hasPersistedValue = false,
  });

  final Set<int> tagIds;
  final Set<int> groupIds;
  final bool hasPersistedValue;
}

class TagMoveSnapshot {
  const TagMoveSnapshot({
    required this.tagId,
    required this.parentTagId,
    required this.groupIds,
  });

  final int tagId;
  final int? parentTagId;
  final Map<int, int?> groupIds;
}

class TagMergeImpact {
  const TagMergeImpact({
    required this.bookmarkCount,
    required this.savedViewCount,
    required this.autoOrganizeRuleCount,
  });

  final int bookmarkCount;
  final int savedViewCount;
  final int autoOrganizeRuleCount;
}

class TagGroupStore {
  TagGroupStore(this.database);

  static const _expansionKey = 'tag_tree_expansion_v1';

  final AppDatabase database;

  static void _debugExpansionStateFallback(StackTrace stackTrace) {
    assert(() {
      stderr.writeln(
        'TagGroupStore: invalid expansion state; using default collapsed state.',
      );
      stderr.writeln(stackTrace);
      return true;
    }());
  }

  TagGroupInfo _toInfo(TagGroupRecord row) => TagGroupInfo(
        id: row.id,
        name: row.name,
        sortOrder: row.sortOrder,
      );

  Future<void> initialize() async {
    // Schema v14 owns tag_groups, tags.group_id and workspace_settings.
  }

  Future<List<TagGroupInfo>> listGroups() async =>
      (await (database.select(database.tagGroups)
                ..orderBy([
                  (group) => OrderingTerm.asc(group.sortOrder),
                  (group) => OrderingTerm.asc(group.name),
                ]))
              .get())
          .map(_toInfo)
          .toList();

  Stream<List<TagGroupInfo>> watchGroups() =>
      (database.select(database.tagGroups)
            ..orderBy([
              (group) => OrderingTerm.asc(group.sortOrder),
              (group) => OrderingTerm.asc(group.name),
            ]))
          .watch()
          .map((rows) => rows.map(_toInfo).toList());

  Future<Map<int, int?>> tagGroupIds() async {
    final rows = await database.select(database.tags).get();
    return {for (final row in rows) row.id: row.groupId};
  }

  Stream<Map<int, int?>> watchTagGroupIds() =>
      database.select(database.tags).watch().map(
            (rows) => {for (final row in rows) row.id: row.groupId},
          );

  Stream<Map<int, TagUsageStats>> watchUsageStats() => database
      .customSelect(
        'WITH RECURSIVE tag_tree(root_id, tag_id) AS ('
        '  SELECT id, id FROM tags '
        '  UNION ALL '
        '  SELECT tag_tree.root_id, child.id '
        '  FROM tag_tree '
        '  JOIN tags child ON child.parent_tag_id = tag_tree.tag_id'
        ') '
        'SELECT tag_tree.root_id AS tag_id, '
        'COUNT(DISTINCT CASE WHEN tag_tree.root_id = tag_tree.tag_id '
        '  THEN bt.bookmark_id END) AS direct_count, '
        'COUNT(DISTINCT bt.bookmark_id) AS aggregate_count '
        'FROM tag_tree '
        'LEFT JOIN bookmark_tags bt ON bt.tag_id = tag_tree.tag_id '
        'GROUP BY tag_tree.root_id',
        readsFrom: {database.tags, database.bookmarkTags},
      )
      .watch()
      .map(
        (rows) => {
          for (final row in rows)
            row.read<int>('tag_id'): TagUsageStats(
              directCount: row.read<int>('direct_count'),
              aggregateCount: row.read<int>('aggregate_count'),
            ),
        },
      );

  Future<Map<int, TagUsageStats>> usageStats() =>
      watchUsageStats().first;

  Future<TagTreeExpansionState> loadExpansionState() async {
    final tags = await database.select(database.tags).get();
    final groups = await database.select(database.tagGroups).get();
    final validTags = tags.map((tag) => tag.id).toSet();
    final validGroups = groups.map((group) => group.id).toSet();
    final row = await (database.select(database.workspaceSettings)
          ..where((setting) => setting.key.equals(_expansionKey)))
        .getSingleOrNull();
    if (row == null) return const TagTreeExpansionState();
    try {
      final decoded = jsonDecode(row.value);
      if (decoded is! Map<String, dynamic>) {
        _debugExpansionStateFallback(StackTrace.current);
        return const TagTreeExpansionState();
      }
      final tagIds = (decoded['tags'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((id) => id.toInt())
          .where(validTags.contains)
          .toSet();
      final groupIds = (decoded['groups'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((id) => id.toInt())
          .where((id) => id == -1 || validGroups.contains(id))
          .toSet();
      return TagTreeExpansionState(
        tagIds: tagIds,
        groupIds: groupIds,
        hasPersistedValue: true,
      );
    } catch (_, stackTrace) {
      _debugExpansionStateFallback(stackTrace);
      return const TagTreeExpansionState();
    }
  }

  Future<void> saveExpansionState(TagTreeExpansionState state) =>
      database.into(database.workspaceSettings).insertOnConflictUpdate(
            WorkspaceSettingsCompanion.insert(
              key: _expansionKey,
              value: jsonEncode({
                'tags': state.tagIds.toList()..sort(),
                'groups': state.groupIds.toList()..sort(),
              }),
            ),
          );

  Future<int> createGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('グループ名が空です');
    final groups = await database.select(database.tagGroups).get();
    final nextOrder = groups.isEmpty
        ? 0
        : groups
                .map((group) => group.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            1;
    return database.into(database.tagGroups).insert(
          TagGroupsCompanion.insert(
            name: trimmed,
            sortOrder: Value(nextOrder),
          ),
        );
  }

  Future<void> renameGroup(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('グループ名が空です');
    await (database.update(database.tagGroups)
          ..where((group) => group.id.equals(id)))
        .write(TagGroupsCompanion(name: Value(trimmed)));
  }

  Future<void> deleteGroup(int id) => database.transaction(() async {
        await (database.update(database.tags)
              ..where((tag) => tag.groupId.equals(id)))
            .write(const TagsCompanion(groupId: Value(null)));
        await (database.delete(database.tagGroups)
              ..where((group) => group.id.equals(id)))
            .go();
      });

  Future<List<Tag>> _allTags() => database.select(database.tags).get();

  Set<int> _subtreeIds(int tagId, List<Tag> tags) {
    final children = <int, List<int>>{};
    for (final tag in tags) {
      final parent = tag.parentTagId;
      if (parent != null) {
        children.putIfAbsent(parent, () => <int>[]).add(tag.id);
      }
    }
    final result = <int>{tagId};
    final pending = <int>[tagId];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      for (final child in children[current] ?? const <int>[]) {
        if (result.add(child)) pending.add(child);
      }
    }
    return result;
  }

  Future<TagMoveSnapshot> moveTag({
    required int tagId,
    int? parentTagId,
    int? groupId,
  }) async {
    final tags = await _allTags();
    final byId = {for (final tag in tags) tag.id: tag};
    final moving = byId[tagId];
    if (moving == null) throw ArgumentError('タグが存在しません');
    if (parentTagId == tagId) {
      throw ArgumentError('自分自身を親にはできません');
    }
    final subtree = _subtreeIds(tagId, tags);
    if (parentTagId != null && subtree.contains(parentTagId)) {
      throw ArgumentError('子孫タグを親にはできません');
    }
    final parent = parentTagId == null ? null : byId[parentTagId];
    if (parentTagId != null && parent == null) {
      throw ArgumentError('親タグが存在しません');
    }
    final destinationGroupId = parent?.groupId ?? groupId;
    if (destinationGroupId != null) {
      final groupExists = await (database.select(database.tagGroups)
            ..where((group) => group.id.equals(destinationGroupId)))
          .getSingleOrNull();
      if (groupExists == null) throw ArgumentError('グループが存在しません');
    }
    final snapshot = TagMoveSnapshot(
      tagId: tagId,
      parentTagId: moving.parentTagId,
      groupIds: {
        for (final id in subtree) id: byId[id]?.groupId,
      },
    );

    await database.transaction(() async {
      await (database.update(database.tags)
            ..where((tag) => tag.id.equals(tagId)))
          .write(TagsCompanion(parentTagId: Value(parentTagId)));
      for (final id in subtree) {
        await (database.update(database.tags)
              ..where((tag) => tag.id.equals(id)))
            .write(TagsCompanion(groupId: Value(destinationGroupId)));
      }
    });
    return snapshot;
  }

  Future<void> restoreMove(TagMoveSnapshot snapshot) =>
      database.transaction(() async {
        await (database.update(database.tags)
              ..where((tag) => tag.id.equals(snapshot.tagId)))
            .write(TagsCompanion(
          parentTagId: Value(snapshot.parentTagId),
        ));
        for (final entry in snapshot.groupIds.entries) {
          await (database.update(database.tags)
                ..where((tag) => tag.id.equals(entry.key)))
              .write(TagsCompanion(groupId: Value(entry.value)));
        }
      });

  Future<void> setTagGroup(int tagId, int? groupId) =>
      moveTag(tagId: tagId, groupId: groupId);

  Future<void> renameTag(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('タグ名が空です');
    final current = await (database.select(database.tags)
          ..where((tag) => tag.id.equals(id)))
        .getSingleOrNull();
    if (current == null) throw ArgumentError('タグが存在しません');
    final duplicate = (await database.select(database.tags).get()).any(
      (tag) =>
          tag.id != id &&
          tag.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) throw ArgumentError('同名のタグが存在します');

    await database.transaction(() async {
      await (database.update(database.tags)
            ..where((tag) => tag.id.equals(id)))
          .write(TagsCompanion(name: Value(trimmed)));
      if (await _autoOrganizeRulesExist()) {
        await database.customStatement(
          'UPDATE auto_organize_rules SET tag_name = ? WHERE tag_name = ?',
          [trimmed, current.name],
        );
      }
    });
  }

  Future<bool> _autoOrganizeRulesExist() async {
    final row = await database.customSelect(
      "SELECT COUNT(*) AS count FROM sqlite_master "
      "WHERE type = 'table' AND name = 'auto_organize_rules'",
    ).getSingle();
    return row.read<int>('count') > 0;
  }

  Future<TagMergeImpact> mergeImpact(int sourceTagId) async {
    final bookmarkRow = await database.customSelect(
      'SELECT COUNT(DISTINCT bookmark_id) AS count '
      'FROM bookmark_tags WHERE tag_id = ?',
      variables: [Variable.withInt(sourceTagId)],
    ).getSingle();
    final viewRow = await database.customSelect(
      'SELECT COUNT(DISTINCT view_id) AS count FROM ('
      'SELECT id AS view_id FROM saved_views WHERE tag_id = ? '
      'UNION ALL '
      'SELECT saved_view_id AS view_id FROM saved_view_tags WHERE tag_id = ?'
      ')',
      variables: [
        Variable.withInt(sourceTagId),
        Variable.withInt(sourceTagId),
      ],
    ).getSingle();
    var ruleCount = 0;
    if (await _autoOrganizeRulesExist()) {
      final source = await (database.select(database.tags)
            ..where((tag) => tag.id.equals(sourceTagId)))
          .getSingle();
      final ruleRow = await database.customSelect(
        'SELECT COUNT(*) AS count FROM auto_organize_rules '
        'WHERE tag_name = ?',
        variables: [Variable.withString(source.name)],
      ).getSingle();
      ruleCount = ruleRow.read<int>('count');
    }
    return TagMergeImpact(
      bookmarkCount: bookmarkRow.read<int>('count'),
      savedViewCount: viewRow.read<int>('count'),
      autoOrganizeRuleCount: ruleCount,
    );
  }

  Future<void> mergeTags({
    required int sourceTagId,
    required int targetTagId,
  }) async {
    if (sourceTagId == targetTagId) {
      throw ArgumentError('同じタグには統合できません');
    }
    final tags = await _allTags();
    final byId = {for (final tag in tags) tag.id: tag};
    final source = byId[sourceTagId];
    final target = byId[targetTagId];
    if (source == null || target == null) {
      throw ArgumentError('タグが存在しません');
    }
    if (_subtreeIds(sourceTagId, tags).contains(targetTagId)) {
      throw ArgumentError('子孫タグへの統合は循環を作るため実行できません');
    }

    await database.transaction(() async {
      await database.customStatement(
        'INSERT OR IGNORE INTO bookmark_tags(bookmark_id, tag_id) '
        'SELECT bookmark_id, ? FROM bookmark_tags WHERE tag_id = ?',
        [targetTagId, sourceTagId],
      );
      await database.customStatement(
        'DELETE FROM bookmark_tags WHERE tag_id = ?',
        [sourceTagId],
      );
      await database.customStatement(
        'UPDATE saved_views SET tag_id = ? WHERE tag_id = ?',
        [targetTagId, sourceTagId],
      );
      await database.customStatement(
        'INSERT OR IGNORE INTO saved_view_tags(saved_view_id, tag_id) '
        'SELECT saved_view_id, ? FROM saved_view_tags WHERE tag_id = ?',
        [targetTagId, sourceTagId],
      );
      await database.customStatement(
        'DELETE FROM saved_view_tags WHERE tag_id = ?',
        [sourceTagId],
      );
      if (await _autoOrganizeRulesExist()) {
        await database.customStatement(
          'UPDATE auto_organize_rules SET tag_name = ? WHERE tag_name = ?',
          [target.name, source.name],
        );
      }
      await (database.update(database.tags)
            ..where((tag) => tag.parentTagId.equals(sourceTagId)))
          .write(TagsCompanion(
        parentTagId: Value(targetTagId),
        groupId: Value(target.groupId),
      ));
      final sourceDescendants = _subtreeIds(sourceTagId, tags)
        ..remove(sourceTagId);
      for (final descendantId in sourceDescendants) {
        await (database.update(database.tags)
              ..where((tag) => tag.id.equals(descendantId)))
            .write(TagsCompanion(groupId: Value(target.groupId)));
      }
      await (database.delete(database.tags)
            ..where((tag) => tag.id.equals(sourceTagId)))
          .go();
    });
  }

  Future<void> deleteTag(int id) async {
    final tag = await (database.select(database.tags)
          ..where((candidate) => candidate.id.equals(id)))
        .getSingleOrNull();
    if (tag == null) return;
    await database.transaction(() async {
      await (database.update(database.tags)
            ..where((candidate) => candidate.parentTagId.equals(id)))
          .write(TagsCompanion(
        parentTagId: Value(tag.parentTagId),
      ));
      if (await _autoOrganizeRulesExist()) {
        await database.customStatement(
          'UPDATE auto_organize_rules SET tag_name = \'\' '
          'WHERE tag_name = ?',
          [tag.name],
        );
      }
      await (database.delete(database.tags)
            ..where((candidate) => candidate.id.equals(id)))
          .go();
    });
  }

  Future<void> deleteUnusedTags(Iterable<int> tagIds) async {
    final ids = tagIds.toSet();
    if (ids.isEmpty) return;
    final stats = await usageStats();
    final invalid = ids.where(
      (id) => (stats[id]?.aggregateCount ?? 0) > 0,
    );
    if (invalid.isNotEmpty) {
      throw StateError('使用中のタグまたは子孫を含むタグは削除できません');
    }
    await database.transaction(() async {
      for (final id in ids) {
        await (database.update(database.tags)
              ..where((tag) =>
                  tag.parentTagId.equals(id) & tag.id.isNotIn(ids)))
            .write(const TagsCompanion(parentTagId: Value(null)));
      }
      await (database.delete(database.tags)
            ..where((tag) => tag.id.isIn(ids)))
          .go();
    });
  }

  Future<void> reorderGroups(List<int> ids) =>
      database.transaction(() async {
        for (var i = 0; i < ids.length; i++) {
          await (database.update(database.tagGroups)
                ..where((group) => group.id.equals(ids[i])))
              .write(TagGroupsCompanion(sortOrder: Value(i)));
        }
      });

  Future<void> dispose() async {}
}
