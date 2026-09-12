import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/generic_database_page_services.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/services/canonical_person_profile_image_relation_edit_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic database composition installs Person Profile Image compatibility router', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);

    final services = GenericDatabasePageServices.fromStores(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    expect(
      services.relationEditor,
      isA<CanonicalPersonProfileImageRelationEditService>(),
    );
  });
}
