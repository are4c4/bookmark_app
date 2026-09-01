import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/tag_group_store.dart';
import 'package:bookmark_app/services/auto_organize_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late TagGroupStore store;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    store = TagGroupStore(database);
    await store.initialize();
  });

  tearDown(() async {
    await database.close();
  });

  Future<Tag> tag(int id) =>
      (database.select(database.tags)..where((row) => row.id.equals(id)))
          .getSingle();

  test('usage counts distinguish direct and deduplicated descendants',
      () async {
    final parentId = await database.createTag('Parent');
    final childId =
        await database.createTag('Child', parentTagId: parentId);
    final grandchildId =
        await database.createTag('Grandchild', parentTagId: childId);
    final first = await database.addBookmark(
      url: 'https://one.example',
      title: 'One',
      tagNames: const [],
    );
    final second = await database.addBookmark(
      url: 'https://two.example',
      title: 'Two',
      tagNames: const [],
    );
    await database.into(database.bookmarkTags).insert(
          BookmarkTagsCompanion.insert(
            bookmarkId: first,
            tagId: childId,
          ),
        );
    await database.into(database.bookmarkTags).insert(
          BookmarkTagsCompanion.insert(
            bookmarkId: first,
            tagId: grandchildId,
          ),
        );
    await database.into(database.bookmarkTags).insert(
          BookmarkTagsCompanion.insert(
            bookmarkId: second,
            tagId: childId,
          ),
        );

    final stats = await store.usageStats();

    expect(stats[parentId]?.directCount, 0);
    expect(stats[parentId]?.aggregateCount, 2);
    expect(stats[childId]?.directCount, 2);
    expect(stats[childId]?.aggregateCount, 2);
    expect(stats[grandchildId]?.aggregateCount, 1);
  });

  test('moving a parent changes descendant groups and undo restores all',
      () async {
    final firstGroup = await store.createGroup('First');
    final secondGroup = await store.createGroup('Second');
    final parentId = await database.createTag('Parent');
    final childId =
        await database.createTag('Child', parentTagId: parentId);
    await store.setTagGroup(parentId, firstGroup);

    final snapshot = await store.moveTag(
      tagId: parentId,
      groupId: secondGroup,
    );
    expect((await tag(parentId)).groupId, secondGroup);
    expect((await tag(childId)).groupId, secondGroup);

    await store.restoreMove(snapshot);
    expect((await tag(parentId)).groupId, firstGroup);
    expect((await tag(childId)).groupId, firstGroup);
  });

  test('cycle creation is rejected in the store layer', () async {
    final parentId = await database.createTag('Parent');
    final childId =
        await database.createTag('Child', parentTagId: parentId);
    final grandchildId =
        await database.createTag('Grandchild', parentTagId: childId);

    expect(
      () => store.moveTag(
        tagId: parentId,
        parentTagId: grandchildId,
      ),
      throwsArgumentError,
    );
  });

  test('merge updates bookmarks views rules and child tags atomically',
      () async {
    final sourceId = await database.createTag('Source');
    final targetId = await database.createTag('Target');
    final childId =
        await database.createTag('Source child', parentTagId: sourceId);
    final grandchildId = await database.createTag(
      'Source grandchild',
      parentTagId: childId,
    );
    final targetGroupId = await store.createGroup('Target group');
    await store.setTagGroup(targetId, targetGroupId);
    final bookmarkId = await database.addBookmark(
      url: 'https://merge.example',
      title: 'Merge',
      tagNames: const [],
    );
    await database.into(database.bookmarkTags).insert(
          BookmarkTagsCompanion.insert(
            bookmarkId: bookmarkId,
            tagId: sourceId,
          ),
        );
    await database.into(database.bookmarkTags).insert(
          BookmarkTagsCompanion.insert(
            bookmarkId: bookmarkId,
            tagId: targetId,
          ),
        );
    await database.createSavedView(
      name: 'Source view',
      layoutType: 'gallery',
      tagIds: [sourceId, targetId],
    );
    final auto = AutoOrganizeService(database);
    await auto.createRule(
      name: 'Source rule',
      matchField: AutoOrganizeMatchField.all,
      keyword: 'example',
      tagName: 'Source',
    );

    final impact = await store.mergeImpact(sourceId);
    expect(impact.bookmarkCount, 1);
    expect(impact.savedViewCount, 1);
    expect(impact.autoOrganizeRuleCount, 1);

    await store.mergeTags(
      sourceTagId: sourceId,
      targetTagId: targetId,
    );

    expect(
      await (database.select(database.tags)
            ..where((row) => row.id.equals(sourceId)))
          .getSingleOrNull(),
      isNull,
    );
    expect((await tag(childId)).parentTagId, targetId);
    expect((await tag(childId)).groupId, targetGroupId);
    expect((await tag(grandchildId)).groupId, targetGroupId);
    final relations = await (database.select(database.bookmarkTags)
          ..where((row) => row.bookmarkId.equals(bookmarkId)))
        .get();
    expect(relations.map((row) => row.tagId), [targetId]);
    final views = await database.watchSavedViewConfigs().first;
    expect(views.single.tags.map((item) => item.id), [targetId]);
    expect((await auto.listRules()).single.tagName, 'Target');
  });

  test('rename updates auto-organize tag references', () async {
    final id = await database.createTag('Before');
    final auto = AutoOrganizeService(database);
    await auto.createRule(
      name: 'Rule',
      matchField: AutoOrganizeMatchField.url,
      keyword: 'example',
      tagName: 'Before',
    );

    await store.renameTag(id, 'After');

    expect((await auto.listRules()).single.tagName, 'After');
  });

  test('expansion state ignores deleted identifiers', () async {
    final id = await database.createTag('Tag');
    final groupId = await store.createGroup('Group');
    await store.saveExpansionState(
      TagTreeExpansionState(
        tagIds: {id, 999},
        groupIds: {groupId, -1, 999},
        hasPersistedValue: true,
      ),
    );

    final state = await store.loadExpansionState();

    expect(state.hasPersistedValue, isTrue);
    expect(state.tagIds, {id});
    expect(state.groupIds, {groupId, -1});
  });

  test('unused parent with a used descendant is protected', () async {
    final parentId = await database.createTag('Parent');
    final childId =
        await database.createTag('Child', parentTagId: parentId);
    final unusedId = await database.createTag('Unused');
    await database.addBookmark(
      url: 'https://used.example',
      title: 'Used',
      tagNames: ['Child'],
    );

    expect(
      () => store.deleteUnusedTags([parentId]),
      throwsStateError,
    );
    await store.deleteUnusedTags([unusedId]);
    expect(
      await (database.select(database.tags)
            ..where((row) => row.id.equals(unusedId)))
          .getSingleOrNull(),
      isNull,
    );
    expect(await tag(childId), isNotNull);
  });
}
