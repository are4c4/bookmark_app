import 'dart:io';

import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/bidirectional_relation_store.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/profile_path_resolver.dart';
import 'package:bookmark_app/data/relation_mutation_service.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/weblink_image_schema_service.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/weblink_visual_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('managed Weblink visuals expose persisted portrait and landscape ratios',
      () async {
    final directory = await Directory.systemTemp.createTemp('weblink_geometry_');
    addTearDown(() => directory.delete(recursive: true));
    final portraitFile = File('${directory.path}/portrait.img');
    final landscapeFile = File('${directory.path}/landscape.img');
    await portraitFile.writeAsBytes(const <int>[1]);
    await landscapeFile.writeAsBytes(const <int>[2]);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final schema = await WeblinkImageSchemaService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);
    final weblinks = WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final images = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );
    final portraitWeblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/portrait',
    );
    final landscapeWeblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/landscape',
    );
    final noMediaWeblink = await weblinks.findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/no-media',
    );
    final portraitImage = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: portraitFile.path,
      pixelWidth: 600,
      pixelHeight: 1200,
    );
    final landscapeImage = await images.findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: landscapeFile.path,
      pixelWidth: 1200,
      pixelHeight: 600,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    await mutations.setRelation(
      objectId: portraitWeblink.id,
      property: schema.representativeImageProperty,
      targetObjectIds: <int>[portraitImage.id],
    );
    await mutations.setRelation(
      objectId: landscapeWeblink.id,
      property: schema.representativeImageProperty,
      targetObjectIds: <int>[landscapeImage.id],
    );

    final resolver = WeblinkVisualResolver(objectStore);
    final portrait = await resolver.resolveManagedRepresentative(
      weblinkObjectTypeId: schema.weblinkObjectTypeId,
      weblinkObjectId: portraitWeblink.id,
    );
    final landscape = await resolver.resolveManagedRepresentative(
      weblinkObjectTypeId: schema.weblinkObjectTypeId,
      weblinkObjectId: landscapeWeblink.id,
    );
    final noMedia = await resolver.resolveManagedRepresentative(
      weblinkObjectTypeId: schema.weblinkObjectTypeId,
      weblinkObjectId: noMediaWeblink.id,
    );

    expect(portrait?.filePath, portraitFile.path);
    expect(portrait?.pixelWidth, 600);
    expect(portrait?.pixelHeight, 1200);
    expect(portrait?.aspectRatio, .5);
    expect(landscape?.filePath, landscapeFile.path);
    expect(landscape?.pixelWidth, 1200);
    expect(landscape?.pixelHeight, 600);
    expect(landscape?.aspectRatio, 2);
    expect(noMedia, isNull);
  });

  test('managed Weblink visual resolves profile-relative Image file', () async {
    final directory = await Directory.systemTemp.createTemp('weblink_relative_');
    addTearDown(() => directory.delete(recursive: true));
    final mediaDirectory = Directory('${directory.path}/managed');
    await mediaDirectory.create(recursive: true);
    final managedFile = File('${mediaDirectory.path}/cover.img');
    await managedFile.writeAsBytes(const <int>[7, 8, 9]);

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final schema = await WeblinkImageSchemaService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).ensureDefinition(workspaceId);
    final weblink = await WeblinkObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).findOrCreate(
      workspaceId: workspaceId,
      url: 'https://example.com/relative-cover',
    );
    final image = await ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    ).findOrCreateManaged(
      workspaceId: workspaceId,
      filePath: 'managed/cover.img',
      pixelWidth: 900,
      pixelHeight: 600,
    );
    final mutations = RelationMutationService(
      objectStore: objectStore,
      genericStore: genericStore,
      bidirectionalStore: BidirectionalRelationStore(
        genericStore: genericStore,
        objectStore: objectStore,
      ),
    );
    await mutations.setRelation(
      objectId: weblink.id,
      property: schema.representativeImageProperty,
      targetObjectIds: <int>[image.id],
    );

    final visual = await WeblinkVisualResolver(
      objectStore,
      pathResolver: ProfilePathResolver(directory.path),
    ).resolveManagedRepresentative(
      weblinkObjectTypeId: schema.weblinkObjectTypeId,
      weblinkObjectId: weblink.id,
    );

    expect(visual?.filePath, managedFile.path);
    expect(visual?.aspectRatio, 1.5);
  });
}
