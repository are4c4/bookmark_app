import 'package:bookmark_app/data/app_database.dart';
import 'package:bookmark_app/data/file_object_service.dart';
import 'package:bookmark_app/data/generic_database_store.dart';
import 'package:bookmark_app/data/image_object_service.dart';
import 'package:bookmark_app/data/object_store.dart';
import 'package:bookmark_app/data/object_type_template_primitive_target_resolver.dart';
import 'package:bookmark_app/data/system_object_store.dart';
import 'package:bookmark_app/data/tag_object_bridge.dart';
import 'package:bookmark_app/data/weblink_object_service.dart';
import 'package:bookmark_app/data/workspace_store.dart';
import 'package:bookmark_app/domain/object_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh workspace provisions canonical template primitive targets', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final resolver = ObjectTypeTemplatePrimitiveTargetResolver(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    for (final key in <String>[
      WeblinkObjectService.systemKey,
      ImageObjectService.systemKey,
      FileObjectService.systemKey,
      TagObjectBridge.systemKey,
    ]) {
      final target = await resolver.resolveOrProvision(
        workspaceId: workspaceId,
        systemKey: key,
      );
      expect(target, isNotNull, reason: key);
      expect(target!.kind, ObjectTypeKind.system, reason: key);
      expect(
        await systemObjects.systemKeyForObjectType(target.id),
        key,
        reason: key,
      );
    }
  });

  test('existing target is reused and unknown system key fails closed', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final workspaceId = await WorkspaceStore(database).initialize();
    final genericStore = GenericDatabaseStore(database);
    final objectStore = ObjectStore(genericStore);
    final systemObjects = SystemObjectStore(
      database: database,
      objectStore: objectStore,
    );
    final existing = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: 'custom-primitive',
      name: 'Custom primitive',
      icon: '🧩',
    );
    final resolver = ObjectTypeTemplatePrimitiveTargetResolver(
      genericStore: genericStore,
      objectStore: objectStore,
    );

    final reused = await resolver.resolveOrProvision(
      workspaceId: workspaceId,
      systemKey: 'custom-primitive',
    );
    final missing = await resolver.resolveOrProvision(
      workspaceId: workspaceId,
      systemKey: 'unknown-primitive',
    );

    expect(reused?.id, existing.id);
    expect(missing, isNull);
  });
}
