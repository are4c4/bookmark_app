import '../domain/object_model.dart';
import '../domain/object_type_defaults.dart';
import 'object_type_defaults_store.dart';
import 'system_object_store.dart';

class ImageObjectDefinition {
  const ImageObjectDefinition({
    required this.objectType,
    required this.fileProperty,
    required this.noteProperty,
  });

  final AppObjectType objectType;
  final ObjectPropertyDefinition fileProperty;
  final ObjectPropertyDefinition noteProperty;
}

/// Stable Object-lane facade for the existing system Image ObjectType.
///
/// `CoreObjectBridge` already mirrors legacy photos into system key `image`.
/// This service deliberately reuses that exact ObjectType and only adds the
/// reusable defaults contract needed by generic Object detail surfaces.
class ImageObjectService {
  ImageObjectService({
    required this.systemObjects,
    required this.defaultsStore,
  });

  static const String systemKey = 'image';

  final SystemObjectStore systemObjects;
  final ObjectTypeDefaultsStore defaultsStore;

  Future<ImageObjectDefinition> ensureDefinition(int workspaceId) async {
    var type = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
      name: '画像',
      icon: '🖼️',
    );
    final file = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'File',
      type: ObjectPropertyType.file,
      config: const <String, dynamic>{'system': true},
    );
    final note = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Note',
      type: ObjectPropertyType.text,
    );
    type = (await systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    ))!;

    final currentDefaults = await defaultsStore.read(type.id);
    if (currentDefaults == null) {
      await defaultsStore.write(
        objectTypeId: type.id,
        defaults: ObjectTypeDefaults(
          visiblePropertyIds: <int>[file.id, note.id],
          propertyOrder: <int>[file.id, note.id],
          openMode: ObjectOpenMode.sidePeek,
        ),
      );
    }

    return ImageObjectDefinition(
      objectType: type,
      fileProperty: file,
      noteProperty: note,
    );
  }
}
