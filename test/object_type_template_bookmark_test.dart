import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bookmark template is a user-owned generic domain over primitive Relations', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final templateStore = ObjectTypeTemplateStore(genericStore);
    final template = templateStore.templateByKey('bookmark')!;

    expect(
      template.properties.map((property) => property.name),
      [
        'Weblink',
        'タグ',
        'カバー',
        'ファイル',
        '評価',
        '状態',
        'お気に入り',
      ],
    );
    expect(
      template.properties.map((property) => property.name),
      isNot(contains('Legacy Bookmark ID')),
    );

    final objectTypeId = await templateStore.createFromTemplate(
      workspaceId: workspaceId,
      template: template,
    );
    final bookmark = (await objectStore.getObjectType(objectTypeId))!;
    expect(bookmark.kind, ObjectTypeKind.custom);

    final primitiveTargets = <String, AppObjectType>{};
    for (final key in <String>[
      WeblinkObjectService.systemKey,
      ImageObjectService.systemKey,
      FileObjectService.systemKey,
      TagObjectBridge.systemKey,
    ]) {
      final target = await systemObjects.getSystemObjectType(
        workspaceId: workspaceId,
        systemKey: key,
      );
      expect(target, isNotNull, reason: key);
      expect(target!.kind, ObjectTypeKind.system, reason: key);
      primitiveTargets[key] = target;
    }

    ObjectPropertyDefinition property(String name) =>
        bookmark.properties.firstWhere((property) => property.name == name);

    final weblink = property('Weblink');
    final tags = property('タグ');
    final cover = property('カバー');
    final files = property('ファイル');
    final rating = property('評価');
    final status = property('状態');
    final favorite = property('お気に入り');

    expect(weblink.type, ObjectPropertyType.objectRelation);
    expect(
      weblink.targetObjectTypeId,
      primitiveTargets[WeblinkObjectService.systemKey]!.id,
    );
    expect(weblink.allowsMultipleRelations, isFalse);
    expect(tags.targetObjectTypeId, primitiveTargets[TagObjectBridge.systemKey]!.id);
    expect(tags.allowsMultipleRelations, isTrue);
    expect(cover.targetObjectTypeId, primitiveTargets[ImageObjectService.systemKey]!.id);
    expect(cover.allowsMultipleRelations, isFalse);
    expect(files.targetObjectTypeId, primitiveTargets[FileObjectService.systemKey]!.id);
    expect(files.allowsMultipleRelations, isTrue);
    expect(rating.type, ObjectPropertyType.rating);
    expect(status.type, ObjectPropertyType.select);
    expect(status.config['options'], ['あとで読む', '読了']);
    expect(favorite.type, ObjectPropertyType.checkbox);

    final views = await DatabaseViewStore(database).listViews(
      workspaceId: workspaceId,
      databaseKey: 'custom:$objectTypeId',
    );
    expect(views.map((view) => view.name), ['すべて', 'あとで読む', 'お気に入り']);
    expect(views.every((view) => view.layoutType == 'gallery'), isTrue);
    for (final view in views) {
      expect(
        const DatabaseViewGalleryAdapter().decodeCoverSource(view),
        GalleryCoverSource.imageRelation(cover.id),
        reason: view.name,
      );
    }

    final all = views.firstWhere((view) => view.name == 'すべて');
    expect(
      all.visibleProperties,
      ['p:${status.id}', 'p:${favorite.id}', 'p:${rating.id}', 'p:${tags.id}'],
    );
    expect(
      all.propertyOrder,
      [
        'p:${weblink.id}',
        'p:${status.id}',
        'p:${favorite.id}',
        'p:${rating.id}',
        'p:${tags.id}',
        'p:${cover.id}',
        'p:${files.id}',
      ],
    );

    final readLater = views.firstWhere((view) => view.name == 'あとで読む');
    expect(readLater.filters['propertyRules'], [
      {
        'propertyId': status.id,
        'operator': 'equals',
        'value': 'あとで読む',
      },
    ]);
    final favorites = views.firstWhere((view) => view.name == 'お気に入り');
    expect(favorites.filters['propertyRules'], [
      {
        'propertyId': favorite.id,
        'operator': 'equals',
        'value': true,
      },
    ]);

    final provenance = await templateStore.instanceForObjectType(objectTypeId);
    expect(provenance?.templateKey, 'bookmark');
    expect(provenance?.templateVersion, 1);

    await objectStore.renameObjectType(objectTypeId, '自分のブックマーク');
    await objectStore.createProperty(
      objectTypeId: objectTypeId,
      name: '自分用メモ',
      type: ObjectPropertyType.text,
    );
    final customized = (await objectStore.getObjectType(objectTypeId))!;
    expect(customized.name, '自分のブックマーク');
    expect(
      customized.properties.map((property) => property.name),
      contains('自分用メモ'),
    );
    expect(
      (await templateStore.instanceForObjectType(objectTypeId))?.templateVersion,
      1,
    );
  });
}
