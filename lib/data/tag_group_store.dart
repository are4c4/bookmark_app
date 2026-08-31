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

class TagGroupStore {
  TagGroupStore(this.database);

  final AppDatabase database;

  TagGroupInfo _toInfo(TagGroupRecord row) => TagGroupInfo(
        id: row.id,
        name: row.name,
        sortOrder: row.sortOrder,
      );

  Future<void> initialize() async {
    // Schema v13 owns tag_groups and tags.group_id.
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

  Stream<List<TagGroupInfo>> watchGroups() => (database.select(database.tagGroups)
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

  Future<int> createGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('グループ名が空です');

    final groups = await database.select(database.tagGroups).get();
    final nextOrder = groups.isEmpty
        ? 0
        : groups.map((group) => group.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    return database.into(database.tagGroups).insert(
          TagGroupsCompanion.insert(
            name: trimmed,
            sortOrder: Value(nextOrder),
          ),
        );
  }

  Future<void> renameGroup(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await (database.update(database.tagGroups)..where((group) => group.id.equals(id))).write(
      TagGroupsCompanion(name: Value(trimmed)),
    );
  }

  Future<void> deleteGroup(int id) => database.transaction(() async {
        await (database.update(database.tags)..where((tag) => tag.groupId.equals(id))).write(
          const TagsCompanion(groupId: Value(null)),
        );
        await (database.delete(database.tagGroups)..where((group) => group.id.equals(id))).go();
      });

  Future<void> setTagGroup(int tagId, int? groupId) async {
    final allTags = await database.select(database.tags).get();
    final childrenByParent = <int, List<int>>{};
    for (final tag in allTags) {
      final parentId = tag.parentTagId;
      if (parentId == null) continue;
      childrenByParent.putIfAbsent(parentId, () => <int>[]).add(tag.id);
    }

    final subtree = <int>{tagId};
    final queue = <int>[tagId];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final childId in childrenByParent[current] ?? const <int>[]) {
        if (subtree.add(childId)) queue.add(childId);
      }
    }

    await database.transaction(() async {
      for (final id in subtree) {
        await (database.update(database.tags)..where((tag) => tag.id.equals(id))).write(
          TagsCompanion(groupId: Value(groupId)),
        );
      }
    });
  }

  Future<void> reorderGroups(List<int> ids) => database.transaction(() async {
        for (var i = 0; i < ids.length; i++) {
          await (database.update(database.tagGroups)..where((group) => group.id.equals(ids[i]))).write(
            TagGroupsCompanion(sortOrder: Value(i)),
          );
        }
      });

  Future<void> dispose() async {}
}
