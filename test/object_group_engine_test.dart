import 'package:bookmark_app/data/object_group_engine.dart';
import 'package:bookmark_app/domain/object_group.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:flutter_test/flutter_test.dart';

AppObject item(int id, String title, dynamic value) => AppObject(
      id: id,
      objectTypeId: 1,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      values: {10: value},
    );

void main() {
  const engine = ObjectGroupEngine();

  test('groups scalar values and places empty group last', () {
    final groups = engine.group(
      objects: [
        item(1, 'A', '進行中'),
        item(2, 'B', null),
        item(3, 'C', '完了'),
        item(4, 'D', '進行中'),
      ],
      rule: const ObjectGroupRule(propertyId: 10),
    );

    expect(groups.map((group) => group.label), ['完了', '進行中', '未設定']);
    expect(groups.first.items.map((object) => object.title), ['C']);
    expect(groups[1].items.map((object) => object.title), ['A', 'D']);
    expect(groups.last.isEmptyGroup, true);
  });

  test('multi-value properties place an Object into each matching group', () {
    final groups = engine.group(
      objects: [
        item(1, 'A', ['数学', '本']),
        item(2, 'B', ['数学']),
      ],
      rule: const ObjectGroupRule(propertyId: 10),
    );

    final math = groups.firstWhere((group) => group.label == '数学');
    final book = groups.firstWhere((group) => group.label == '本');
    expect(math.items.map((object) => object.id), [1, 2]);
    expect(book.items.map((object) => object.id), [1]);
  });

  test('relation JSON objectIds are grouped independently', () {
    final groups = engine.group(
      objects: [item(1, 'A', {'objectIds': [20, 30]})],
      rule: const ObjectGroupRule(propertyId: 10),
    );
    expect(groups.map((group) => group.label).toSet(), {'20', '30'});
  });

  test('empty group can be excluded and computed values can be resolved', () {
    final objects = [item(1, 'A', null), item(2, 'B', null)];
    final groups = engine.group(
      objects: objects,
      rule: const ObjectGroupRule(propertyId: 10, includeEmpty: false),
      valueResolver: (object, propertyId) => object.id == 1 ? '高' : null,
    );
    expect(groups, hasLength(1));
    expect(groups.single.label, '高');
  });

  test('group rule supports JSON round-trip', () {
    final restored = ObjectGroupRule.fromJson(
      const {'propertyId': '12', 'includeEmpty': false},
    );
    expect(restored?.propertyId, 12);
    expect(restored?.includeEmpty, false);
    expect(ObjectGroupRule.fromJson('broken'), isNull);
  });
}
