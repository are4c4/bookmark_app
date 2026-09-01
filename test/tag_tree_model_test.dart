import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/tag_group_store.dart';
import 'package:bookmark_app/views/tag_tree_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime.utc(2026);
  late Tag parent;
  late Tag child;
  late Tag match;
  late TagGroupInfo group;
  late List<Tag> tags;
  late Map<int, int?> groups;

  setUp(() {
    group = const TagGroupInfo(id: 10, name: '技術', sortOrder: 0);
    parent = Tag(
      id: 1,
      name: '開発',
      parentTagId: null,
      groupId: 10,
      createdAt: date,
    );
    child = Tag(
      id: 2,
      name: 'モバイル',
      parentTagId: 1,
      groupId: 10,
      createdAt: date,
    );
    match = Tag(
      id: 3,
      name: 'Flutter',
      parentTagId: 2,
      groupId: 10,
      createdAt: date,
    );
    tags = [parent, child, match];
    groups = {1: 10, 2: 10, 3: 10};
  });

  test('search includes group and every ancestor and expands temporarily', () {
    final model = TagTreeModel.build(
      tags: tags,
      groups: [group],
      groupByTag: groups,
      usage: const {},
      expandedTagIds: const {},
      expandedGroupIds: const {},
      query: 'flutter',
    );

    expect(
      model.rows.map((row) => row.tag?.name ?? row.label),
      ['技術', '開発', 'モバイル', 'Flutter'],
    );
    expect(model.matchingTagIds, {3});
    expect(model.rows.where((row) => row.hasChildren).every(
          (row) => row.expanded,
        ), isTrue);
  });

  test('normal view respects the persisted collapsed state', () {
    final collapsed = TagTreeModel.build(
      tags: tags,
      groups: [group],
      groupByTag: groups,
      usage: const {},
      expandedTagIds: const {},
      expandedGroupIds: const {},
    );
    final expanded = TagTreeModel.build(
      tags: tags,
      groups: [group],
      groupByTag: groups,
      usage: const {},
      expandedTagIds: {1, 2},
      expandedGroupIds: {10},
    );

    expect(collapsed.rows.map((row) => row.label), ['技術']);
    expect(
      expanded.rows.map((row) => row.tag?.name ?? row.label),
      ['技術', '開発', 'モバイル', 'Flutter'],
    );
  });

  test('unused filter uses direct counts while keeping ancestor paths', () {
    final model = TagTreeModel.build(
      tags: tags,
      groups: [group],
      groupByTag: groups,
      usage: const {
        1: TagUsageStats(directCount: 0, aggregateCount: 1),
        2: TagUsageStats(directCount: 0, aggregateCount: 1),
        3: TagUsageStats(directCount: 1, aggregateCount: 1),
      },
      expandedTagIds: const {},
      expandedGroupIds: const {},
      filter: TagUsageFilter.unused,
    );

    expect(model.matchingTagIds, {1, 2});
    expect(
      model.rows.map((row) => row.tag?.name ?? row.label),
      ['技術', '開発', 'モバイル'],
    );
  });
}
