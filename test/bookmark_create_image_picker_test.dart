import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/services/bookmark_image_relation_service.dart';
import 'package:bookmark_app/widgets/bookmark_create_image_picker.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bookmark create Image picker returns canonical selection and cover',
      (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final images = ImageObjectService(
      systemObjects: SystemObjectStore(
        database: database,
        objectStore: objectStore,
      ),
      defaultsStore: ObjectTypeDefaultsStore(genericStore),
    );
    final definition = await images.ensureDefinition(workspaceId);
    final imageAId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Picker Image A',
    );
    final imageBId = await objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: 'Picker Image B',
    );
    final service = BookmarkImageRelationService(database);
    BookmarkCreateImagePickerResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showBookmarkCreateImagePicker(
                  context: context,
                  service: service,
                  workspaceId: workspaceId,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();

    Future<void> pumpUntil(Finder finder) async {
      for (var attempt = 0; attempt < 40; attempt += 1) {
        if (finder.evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(finder, findsWidgets);
    }

    await pumpUntil(find.text('Picker Image A'));
    expect(find.text('Picker Image B'), findsOneWidget);

    await tester.tap(find.text('Picker Image A'));
    await tester.pump();
    await tester.tap(
      find.byKey(ValueKey('bookmark-create-image-cover-$imageBId')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('bookmark-create-image-picker-save')),
    );
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.selectedObjectIds, <int>{imageAId, imageBId});
    expect(result!.coverImageObjectId, imageBId);
  });
}
