import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newer template versions never rewrite an existing user-owned instance',
      () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final templates = ObjectTypeTemplateStore(genericStore);

    const version1 = ObjectTypeTemplate(
      key: 'reading-list-regression',
      version: 1,
      name: 'Reading List',
      icon: '📚',
      description: 'version ownership regression',
      properties: [
        ObjectTypeTemplateProperty(name: 'Status', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(name: 'All', layoutType: 'table'),
      ],
    );
    const version2 = ObjectTypeTemplate(
      key: 'reading-list-regression',
      version: 2,
      name: 'Reading List',
      icon: '📖',
      description: 'newer defaults must only affect new instances',
      properties: [
        ObjectTypeTemplateProperty(name: 'Status', type: 'text'),
        ObjectTypeTemplateProperty(name: 'Rating', type: 'rating'),
      ],
      views: [
        ObjectTypeTemplateView(name: 'Library', layoutType: 'gallery'),
      ],
    );

    final originalId = await templates.createFromTemplate(
      workspaceId: workspaceId,
      template: version1,
    );
    await objectStore.renameObjectType(originalId, 'My Reading Queue');
    await objectStore.createProperty(
      objectTypeId: originalId,
      name: 'My Notes',
      type: ObjectPropertyType.text,
    );

    final newerId = await templates.createFromTemplate(
      workspaceId: workspaceId,
      template: version2,
    );

    final original = (await objectStore.getObjectType(originalId))!;
    expect(original.name, 'My Reading Queue');
    expect(
      original.properties.map((property) => property.name),
      ['Status', 'My Notes'],
    );
    expect(
      (await templates.instanceForObjectType(originalId))?.templateVersion,
      1,
    );

    final newer = (await objectStore.getObjectType(newerId))!;
    expect(newer.name, 'Reading List');
    expect(newer.icon, '📖');
    expect(
      newer.properties.map((property) => property.name),
      ['Status', 'Rating'],
    );
    expect(
      (await templates.instanceForObjectType(newerId))?.templateVersion,
      2,
    );

    expect(newerId, isNot(originalId));
  });
}
