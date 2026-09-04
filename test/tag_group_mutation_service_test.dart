import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/tag_group_mutation_service.dart';
import 'package:bookmark_app/data/tag_group_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late TagGroupStore store;
  late TagGroupMutationService service;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = TagGroupStore(database);
    await store.initialize();
    service = TagGroupMutationService(store);
  });

  tearDown(() => database.close());

  test('create rejects duplicate Tag Group name without raw SQLite error',
      () async {
    await service.createGroup('属性');

    await expectLater(
      service.createGroup(' 属性 '),
      throwsA(
        isA<TagGroupNameConflictException>().having(
          (error) => error.toString(),
          'message',
          '同じ名前のタググループが既にあります',
        ),
      ),
    );
    expect(await store.listGroups(), hasLength(1));
  });

  test('rename rejects another existing name but allows its current name',
      () async {
    final first = await service.createGroup('属性');
    final second = await service.createGroup('分類');

    await service.renameGroup(first, '属性');
    await expectLater(
      service.renameGroup(second, '属性'),
      throwsA(isA<TagGroupNameConflictException>()),
    );

    final groups = await store.listGroups();
    expect(groups.singleWhere((group) => group.id == second).name, '分類');
  });

  test('delete frees the Tag Group name for a later create', () async {
    final id = await service.createGroup('属性');
    await service.deleteGroup(id);

    final recreated = await service.createGroup('属性');
    expect(recreated, isNot(id));
    expect((await store.listGroups()).single.name, '属性');
  });
}
