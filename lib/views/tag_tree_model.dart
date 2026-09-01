import '../data/app_database.dart';
import '../data/tag_group_store.dart';

enum TagUsageFilter {
  all('すべて'),
  used('使用中'),
  unused('未使用');

  const TagUsageFilter(this.label);
  final String label;
}

enum TagTreeRowKind { group, tag }

class TagTreeRow {
  const TagTreeRow.group({
    required this.groupId,
    required this.label,
    required this.expanded,
    required this.hasChildren,
  })  : kind = TagTreeRowKind.group,
        tag = null,
        depth = 0,
        directCount = 0,
        aggregateCount = 0,
        searchMatch = false;

  const TagTreeRow.tag({
    required this.tag,
    required this.depth,
    required this.expanded,
    required this.hasChildren,
    required this.directCount,
    required this.aggregateCount,
    required this.searchMatch,
  })  : kind = TagTreeRowKind.tag,
        groupId = null,
        label = '';

  final TagTreeRowKind kind;
  final int? groupId;
  final String label;
  final Tag? tag;
  final int depth;
  final bool expanded;
  final bool hasChildren;
  final int directCount;
  final int aggregateCount;
  final bool searchMatch;

  String get focusKey =>
      kind == TagTreeRowKind.group ? 'group:${groupId ?? 'other'}' : 'tag:${tag!.id}';
}

class TagTreeModel {
  const TagTreeModel({
    required this.rows,
    required this.matchingTagIds,
    required this.allowedTagIds,
  });

  final List<TagTreeRow> rows;
  final Set<int> matchingTagIds;
  final Set<int> allowedTagIds;

  static TagTreeModel build({
    required List<Tag> tags,
    required List<TagGroupInfo> groups,
    required Map<int, int?> groupByTag,
    required Map<int, TagUsageStats> usage,
    required Set<int> expandedTagIds,
    required Set<int> expandedGroupIds,
    String query = '',
    TagUsageFilter filter = TagUsageFilter.all,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final byId = {for (final tag in tags) tag.id: tag};
    final childrenByParent = <int?, List<Tag>>{};
    for (final tag in tags) {
      childrenByParent.putIfAbsent(tag.parentTagId, () => []).add(tag);
    }
    for (final children in childrenByParent.values) {
      children.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    bool passes(Tag tag) {
      final stats = usage[tag.id] ??
          const TagUsageStats(directCount: 0, aggregateCount: 0);
      final queryMatches = normalizedQuery.isEmpty ||
          tag.name.toLowerCase().contains(normalizedQuery);
      final filterMatches = switch (filter) {
        TagUsageFilter.all => true,
        TagUsageFilter.used => stats.directCount > 0,
        TagUsageFilter.unused => stats.directCount == 0,
      };
      return queryMatches && filterMatches;
    }

    final matching = tags.where(passes).map((tag) => tag.id).toSet();
    final filtering =
        normalizedQuery.isNotEmpty || filter != TagUsageFilter.all;
    final allowed = filtering ? <int>{...matching} : tags.map((tag) => tag.id).toSet();
    if (filtering) {
      for (final id in matching.toList()) {
        var parentId = byId[id]?.parentTagId;
        final visited = <int>{};
        while (parentId != null && visited.add(parentId)) {
          allowed.add(parentId);
          parentId = byId[parentId]?.parentTagId;
        }
      }
    }

    final rows = <TagTreeRow>[];

    void addTags(int? parentId, int depth, int? groupId) {
      final children = (childrenByParent[parentId] ?? const <Tag>[])
          .where(
            (tag) =>
                allowed.contains(tag.id) &&
                (groupByTag[tag.id] ?? tag.groupId) == groupId,
          )
          .toList();
      for (final tag in children) {
        final nested = (childrenByParent[tag.id] ?? const <Tag>[])
            .where((child) => allowed.contains(child.id))
            .toList();
        final expanded = filtering || expandedTagIds.contains(tag.id);
        final stats = usage[tag.id] ??
            const TagUsageStats(directCount: 0, aggregateCount: 0);
        rows.add(
          TagTreeRow.tag(
            tag: tag,
            depth: depth,
            expanded: expanded,
            hasChildren: nested.isNotEmpty,
            directCount: stats.directCount,
            aggregateCount: stats.aggregateCount,
            searchMatch: matching.contains(tag.id),
          ),
        );
        if (nested.isNotEmpty && expanded) {
          addTags(tag.id, depth + 1, groupId);
        }
      }
    }

    final orderedGroups = [...groups]
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0
            ? order
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final groupEntries = <({int? id, String label})>[
      for (final group in orderedGroups) (id: group.id, label: group.name),
      (id: null, label: 'その他タグ'),
    ];

    for (final entry in groupEntries) {
      final groupTagIds = tags
          .where(
            (tag) =>
                allowed.contains(tag.id) &&
                (groupByTag[tag.id] ?? tag.groupId) == entry.id,
          )
          .map((tag) => tag.id)
          .toSet();
      if (groupTagIds.isEmpty) continue;
      final expanded =
          filtering || expandedGroupIds.contains(entry.id ?? -1);
      rows.add(
        TagTreeRow.group(
          groupId: entry.id,
          label: entry.label,
          expanded: expanded,
          hasChildren: groupTagIds.isNotEmpty,
        ),
      );
      if (expanded) addTags(null, 0, entry.id);
    }

    return TagTreeModel(
      rows: rows,
      matchingTagIds: matching,
      allowedTagIds: allowed,
    );
  }
}
