import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/views/object_inspector_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Object inspector composes Image panel only for canonical Image Objects',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final workspaceId = await WorkspaceStore(database).initialize();
      final genericStore = GenericDatabaseStore(database);
      final objectStore = ObjectStore(genericStore);
      final systemObjects = SystemObjectStore(
        database: database,
        objectStore: objectStore,
      );
      final images = ImageObjectService(
        systemObjects: systemObjects,
        defaultsStore: ObjectTypeDefaultsStore(genericStore),
      );
      final imageDefinition = await images.ensureDefinition(workspaceId);
      final nativeImage = await images.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/native.png',
        title: 'Native image',
        originalFilename: 'native.png',
      );
      final legacyImage = await images.findOrCreateManaged(
        workspaceId: workspaceId,
        filePath: '/managed/legacy.png',
        title: 'Legacy mirror',
        originalFilename: 'legacy.png',
      );
      final legacyPhotoId = await systemObjects.ensureProperty(
        objectTypeId: imageDefinition.objectType.id,
        name: 'Legacy Photo ID',
        type: ObjectPropertyType.number,
        config: const {'system': true, 'hidden': true},
      );
      await objectStore.setPropertyValue(
        objectId: legacyImage.id,
        property: legacyPhotoId,
        value: 42,
      );

      final customTypeId = await objectStore.createObjectType(
        workspaceId: workspaceId,
        name: 'Image-like custom type',
      );
      await objectStore.createProperty(
        objectTypeId: customTypeId,
        name: 'File',
        type: ObjectPropertyType.text,
      );
      final customObjectId = await objectStore.createObject(
        objectTypeId: customTypeId,
        title: 'Custom image-like object',
      );

      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pumpInspector(int objectId) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ObjectInspectorPage(
              key: ValueKey('inspector-$objectId'),
              store: genericStore,
              objectStore: objectStore,
              objectId: objectId,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpInspector(nativeImage.id);
      expect(
        find.byKey(ValueKey('object-image-detail-panel-${nativeImage.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('object-image-edit-actions-${nativeImage.id}')),
        findsOneWidget,
      );

      await pumpInspector(legacyImage.id);
      expect(
        find.byKey(ValueKey('object-image-detail-panel-${legacyImage.id}')),
        findsOneWidget,
      );

      await pumpInspector(customObjectId);
      expect(
        find.byKey(ValueKey('object-image-detail-panel-$customObjectId')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('object-image-rotate-left')),
        findsNothing,
      );
    },
  );
}
