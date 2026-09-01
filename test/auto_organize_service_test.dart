import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bookmark_lifecycle_store.dart';
import 'package:bookmark_app/data/bookmark_repository.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/auto_organize_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BookmarkLifecycleStore lifecycleStore;
  late BookmarkRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final workspaceStore = WorkspaceStore(database);
    final workspaceId = await workspaceStore.initialize();
    lifecycleStore = BookmarkLifecycleStore(database);
    await lifecycleStore.initialize();
    repository = BookmarkRepository(
      database,
      workspaceStore: workspaceStore,
      lifecycleStore: lifecycleStore,
      workspaceId: workspaceId,
    );
  });

  tearDown(() async {
    await lifecycleStore.dispose();
    await database.close();
  });

  test('new bookmarks receive matching tag and genre automatically', () async {
    await repository.createAutoOrganizeRule(
      name: 'YouTubeを動画へ',
      matchField: AutoOrganizeMatchField.url,
      keyword: 'youtube.com',
      tagName: 'YouTube',
      genre: '動画',
    );

    await repository.create(
      url: 'https://www.youtube.com/watch?v=example',
      title: 'テスト動画',
    );

    final items = await repository.watchAll().first;
    expect(items, hasLength(1));
    expect(items.single.genre, '動画');
    expect(items.single.tags.map((tag) => tag.name), contains('YouTube'));
  });

  test('disabled rules are not applied', () async {
    final ruleId = await repository.createAutoOrganizeRule(
      name: 'Flutter',
      matchField: AutoOrganizeMatchField.title,
      keyword: 'Flutter',
      tagName: '開発',
    );
    await repository.setAutoOrganizeRuleEnabled(ruleId, false);

    await repository.create(
      url: 'https://example.com',
      title: 'Flutter入門',
    );

    final item = (await repository.watchAll().first).single;
    expect(item.tags, isEmpty);
    expect(item.genre, isEmpty);
  });

  test('existing bookmarks can be organized in a batch', () async {
    await repository.create(
      url: 'https://dart.dev',
      title: 'Dart documentation',
    );
    await repository.create(
      url: 'https://example.com',
      title: 'Other page',
    );
    await repository.createAutoOrganizeRule(
      name: 'Dart',
      matchField: AutoOrganizeMatchField.all,
      keyword: 'dart',
      tagName: 'Dart',
    );

    final result = await repository.applyAutoOrganizeToAll();

    expect(result.bookmarksChanged, 1);
    expect(result.rulesMatched, 1);
    final items = await repository.watchAll().first;
    final dartItem = items.singleWhere((item) => item.url.contains('dart.dev'));
    expect(dartItem.tags.map((tag) => tag.name), contains('Dart'));
  });
}
