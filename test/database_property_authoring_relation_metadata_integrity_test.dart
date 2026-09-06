import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/database_property_authoring_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-Relation Property rejects Relation cardinality metadata', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final objectStore = ObjectStore(GenericDatabaseStore(database));
    final service = DatabasePropertyAuthoringService(objectStore);
    final objectTypeId = await objectStore.createObjectType(
      workspaceId: workspaceId,
      name: 'Project',
    );

    await expectLater(
      service.createProperty(
        objectTypeId: objectTypeId,
        name: 'Broken text',
        type: ObjectPropertyType.text,
        relationMultiple: false,
      ),
      throwsArgumentError,
    );

    final type = await objectStore.getObjectType(objectTypeId);
    expect(type!.properties, isEmpty);
  });
}
