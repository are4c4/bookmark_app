import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_view_gallery_adapter.dart';
import 'package:bookmark_app/data/database_view_query_adapter.dart';
import 'package:bookmark_app/data/database_view_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_query_engine.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/object_type_template_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Bookmark template runs through generic Object Relation and View contracts',
    () async {
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

      final bookmarkTypeId = await templateStore.createFromTemplate(
        workspaceId: workspaceId,
        template: templateStore.templateByKey('bookmark')!,
      );
      final bookmarkType = (await objectStore.getObjectType(bookmarkTypeId))!;
      expect(bookmarkType.kind, ObjectTypeKind.custom);

      final weblinkProperty = bookmarkType.properties.singleWhere(
        (property) => property.name == 'Weblink',
      );
      final coverProperty = bookmarkType.properties.singleWhere(
        (property) => property.name == 'カバー',
      );
      final statusProperty = bookmarkType.properties.singleWhere(
        (property) => property.name == '状態',
      );
      final favoriteProperty = bookmarkType.properties.singleWhere(
        (property) => property.name == 'お気に入り',
      );
      final ratingProperty = bookmarkType.properties.singleWhere(
        (property) => property.name == '評価',
      );

      final weblinkService = WeblinkObjectService(
        systemObjects: systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );
      final weblink = await weblinkService.findOrCreate(
        workspaceId: workspaceId,
        url: 'https://example.com/article',
        title: 'Example article',
      );

      final savedId = await objectStore.createObject(
        objectTypeId: bookmarkTypeId,
        title: 'Saved article',
      );
      await objectStore.setRelation(
        objectId: savedId,
        property: weblinkProperty,
        targetObjectIds: [weblink.id],
      );
      await objectStore.setPropertyValue(
        objectId: savedId,
        property: statusProperty,
        value: 'あとで読む',
      );
      await objectStore.setPropertyValue(
        objectId: savedId,
        property: favoriteProperty,
        value: true,
      );
      await objectStore.setPropertyValue(
        objectId: savedId,
        property: ratingProperty,
        value: 5,
      );

      final readId = await objectStore.createObject(
        objectTypeId: bookmarkTypeId,
        title: 'Read article',
      );
      await objectStore.setPropertyValue(
        objectId: readId,
        property: statusProperty,
        value: '読了',
      );
      await objectStore.setPropertyValue(
        objectId: readId,
        property: favoriteProperty,
        value: false,
      );

      final objects = await objectStore.listObjects(bookmarkTypeId);
      final saved = objects.singleWhere((object) => object.id == savedId);
      final related = await objectStore.resolveRelation(
        weblinkProperty,
        saved.values[weblinkProperty.id],
      );
      expect(related.map((object) => object.id), [weblink.id]);
      expect(saved.values[ratingProperty.id], 5);

      final views = await DatabaseViewStore(database).listViews(
        workspaceId: workspaceId,
        databaseKey: 'custom:$bookmarkTypeId',
      );
      expect(views.map((view) => view.name), ['すべて', 'あとで読む', 'お気に入り']);

      final allView = views.singleWhere((view) => view.name == 'すべて');
      expect(allView.layoutType, 'gallery');
      expect(
        const DatabaseViewGalleryAdapter().decodeCoverSource(allView),
        GalleryCoverSource.imageRelation(coverProperty.id),
      );

      final readLaterView = views.singleWhere((view) => view.name == 'あとで読む');
      final readLaterQuery = const DatabaseViewQueryAdapter().decode(readLaterView);
      expect(
        const ObjectQueryEngine()
            .apply(
              objects: objects,
              filters: readLaterQuery.filters,
              sorts: readLaterQuery.sorts,
            )
            .map((object) => object.title),
        ['Saved article'],
      );

      final favoritesView = views.singleWhere((view) => view.name == 'お気に入り');
      final favoritesQuery = const DatabaseViewQueryAdapter().decode(favoritesView);
      expect(
        const ObjectQueryEngine()
            .apply(
              objects: objects,
              filters: favoritesQuery.filters,
              sorts: favoritesQuery.sorts,
            )
            .map((object) => object.title),
        ['Saved article'],
      );

      expect(
        (await templateStore.instanceForObjectType(bookmarkTypeId))?.templateKey,
        'bookmark',
      );
    },
  );
}
