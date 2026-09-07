import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new template versions do not rewrite an existing user-owned View', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final templateStore = ObjectTypeTemplateStore(genericStore);
    final viewStore = DatabaseViewStore(database);

    const version1 = ObjectTypeTemplate(
      key: 'view-ownership-regression',
      version: 1,
      name: 'Paper',
      icon: '📄',
      description: 'Version 1',
      properties: [
        ObjectTypeTemplateProperty(name: 'Status', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Inbox',
          layoutType: 'table',
          settings: {'openMode': 'sidePeek'},
        ),
      ],
    );

    final firstObjectTypeId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: version1,
    );
    final firstType = await objectStore.getObjectType(firstObjectTypeId);
    final statusProperty = firstType!.properties.singleWhere(
      (property) => property.name == 'Status',
    );
    final firstDatabaseKey = 'custom:$firstObjectTypeId';
    final initialView = (await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: firstDatabaseKey,
    ))
        .single;

    final customizedSettings = <String, dynamic>{
      ...initialView.settings,
      'openMode': 'fullPage',
      'galleryMode': 'masonry',
    };
    await viewStore.updateView(
      initialView.copyWith(
        name: 'My Inbox',
        layoutType: 'gallery',
        visibleProperties: ['p:${statusProperty.id}'],
        propertyOrder: ['p:${statusProperty.id}'],
        settings: customizedSettings,
      ),
    );

    const version2 = ObjectTypeTemplate(
      key: 'view-ownership-regression',
      version: 2,
      name: 'Paper',
      icon: '📄',
      description: 'Version 2',
      properties: [
        ObjectTypeTemplateProperty(name: 'Status', type: 'text'),
        ObjectTypeTemplateProperty(name: 'Notes', type: 'text'),
      ],
      views: [
        ObjectTypeTemplateView(
          name: 'Library',
          layoutType: 'list',
          settings: {'openMode': 'centerPeek'},
        ),
      ],
    );

    final secondObjectTypeId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: version2,
    );
    expect(secondObjectTypeId, isNot(firstObjectTypeId));

    final preservedView = (await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: firstDatabaseKey,
    ))
        .single;
    expect(preservedView.id, initialView.id);
    expect(preservedView.name, 'My Inbox');
    expect(preservedView.layoutType, 'gallery');
    expect(preservedView.visibleProperties, ['p:${statusProperty.id}']);
    expect(preservedView.propertyOrder, ['p:${statusProperty.id}']);
    expect(preservedView.settings['openMode'], 'fullPage');
    expect(preservedView.settings['galleryMode'], 'masonry');

    final secondViews = await viewStore.listViews(
      workspaceId: workspaceId,
      databaseKey: 'custom:$secondObjectTypeId',
    );
    expect(secondViews, hasLength(1));
    expect(secondViews.single.name, 'Library');
    expect(secondViews.single.layoutType, 'list');
    expect(secondViews.single.settings['openMode'], 'centerPeek');

    final firstProvenance = await templateStore.instanceForObjectType(
      firstObjectTypeId,
    );
    final secondProvenance = await templateStore.instanceForObjectType(
      secondObjectTypeId,
    );
    expect(firstProvenance?.templateKey, version1.key);
    expect(firstProvenance?.templateVersion, 1);
    expect(secondProvenance?.templateKey, version2.key);
    expect(secondProvenance?.templateVersion, 2);
  });
}
