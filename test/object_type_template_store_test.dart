import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('built-in templates expose stable unique keys and useful schemas', () {
    final templates = ObjectTypeTemplateStore.templates;
    final keys = templates.map((item) => item.key).toList();
    expect(keys.toSet().length, keys.length);
    expect(keys.toSet(), {
      'book',
      'person',
      'project',
      'note',
    });
    expect(
      templates.firstWhere((item) => item.key == 'book').properties
          .map((property) => property.name),
      containsAll(['著者', '状態', '評価', 'URL', 'メモ']),
    );
  });

  test('createFromTemplate creates database and ordered properties atomically', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final templateStore = ObjectTypeTemplateStore(genericStore);
    final template = templateStore.templateByKey('project')!;

    final databaseId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: template,
      name: '修論プロジェクト',
    );

    final created = await genericStore.getDatabase(databaseId);
    expect(created?.name, '修論プロジェクト');
    expect(created?.icon, '🚀');

    final properties = await genericStore.listProperties(databaseId);
    expect(
      properties.map((property) => property.name).toList(),
      ['状態', '期限', '優先度', 'メモ'],
    );
    expect(properties.first.type, 'select');
    expect(
      properties.first.config['options'],
      ['未着手', '進行中', '完了', '保留'],
    );
  });

  test('template defaults can be overridden without mutating template', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final templateStore = ObjectTypeTemplateStore(genericStore);
    final template = templateStore.templateByKey('note')!;

    final databaseId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: template,
      name: '研究メモ',
      icon: '🧠',
    );

    final created = await genericStore.getDatabase(databaseId);
    expect(created?.name, '研究メモ');
    expect(created?.icon, '🧠');
    expect(template.name, 'ノート');
    expect(template.icon, '📝');
  });
}
