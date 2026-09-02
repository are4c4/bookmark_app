import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_defaults_store.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:bookmark_app/domain/object_type_defaults.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Image definition reuses system image type and installs defaults', () async {
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
    final service = ImageObjectService(
      systemObjects: systemObjects,
      defaultsStore: defaultsStore,
    );

    final first = await service.ensureDefinition(workspaceId);
    final second = await service.ensureDefinition(workspaceId);

    expect(second.objectType.id, first.objectType.id);
    expect(first.objectType.kind, ObjectTypeKind.system);
    expect(first.fileProperty.type, ObjectPropertyType.file);
    expect(first.noteProperty.type, ObjectPropertyType.text);
    expect(
      second.objectType.properties.where((property) => property.name == 'File').length,
      1,
    );
    expect(
      second.objectType.properties.where((property) => property.name == 'Note').length,
      1,
    );
    final defaults = await defaultsStore.read(first.objectType.id);
    expect(defaults?.visiblePropertyIds, <int>[
      first.fileProperty.id,
      first.noteProperty.id,
    ]);
    expect(defaults?.openMode, ObjectOpenMode.sidePeek);
  });
}
