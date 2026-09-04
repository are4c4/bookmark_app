import 'package:bookmark_app/data/tag_group_store.dart';
import 'package:bookmark_app/views/tag_tree_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const emptyGroup = TagGroupInfo(id: 10, name: '属性', sortOrder: 0);

  test('persisted empty group stays visible in the normal Tag tree', () {
    final model = TagTreeModel.build(
      tags: const [],
      groups: const [emptyGroup],
      groupByTag: const {},
      usage: const {},
      expandedTagIds: const {},
      expandedGroupIds: const {10},
    );

    expect(model.rows, hasLength(1));
    final row = model.rows.single;
    expect(row.kind, TagTreeRowKind.group);
    expect(row.groupId, 10);
    expect(row.label, '属性');
    expect(row.hasChildren, isFalse);
  });

  test('synthetic other group remains hidden when it is empty', () {
    final model = TagTreeModel.build(
      tags: const [],
      groups: const [],
      groupByTag: const {},
      usage: const {},
      expandedTagIds: const {},
      expandedGroupIds: const {-1},
    );

    expect(model.rows, isEmpty);
  });

  test('search and usage filtering do not surface unrelated empty groups', () {
    final model = TagTreeModel.build(
      tags: const [],
      groups: const [emptyGroup],
      groupByTag: const {},
      usage: const {},
      expandedTagIds: const {},
      expandedGroupIds: const {},
      query: 'flutter',
    );

    expect(model.rows, isEmpty);
  });
}
