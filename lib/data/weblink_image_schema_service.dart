import '../domain/object_model.dart';
import 'image_object_service.dart';
import 'object_type_defaults_store.dart';
import 'system_object_store.dart';
import 'weblink_object_service.dart';

class WeblinkImageSchemaDefinition {
  const WeblinkImageSchemaDefinition({
    required this.weblinkObjectTypeId,
    required this.imageObjectTypeId,
    required this.representativeImageProperty,
    required this.relatedImagesProperty,
  });

  final int weblinkObjectTypeId;
  final int imageObjectTypeId;
  final ObjectPropertyDefinition representativeImageProperty;
  final ObjectPropertyDefinition relatedImagesProperty;
}

/// Owns only the Object schema for Weblink -> Image Relations.
///
/// Relation writes deliberately remain behind the generic canonical
/// RelationMutationService boundary. This service only ensures and validates
/// the two system Properties required by the Weblink/Image model.
class WeblinkImageSchemaService {
  WeblinkImageSchemaService({
    required this.systemObjects,
    required this.defaultsStore,
  });

  static const representativeImageName = 'Representative image';
  static const relatedImagesName = 'Related images';

  final SystemObjectStore systemObjects;
  final ObjectTypeDefaultsStore defaultsStore;

  late final WeblinkObjectService _weblinks = WeblinkObjectService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      );
  late final ImageObjectService _images = ImageObjectService(
        systemObjects: systemObjects,
        defaultsStore: defaultsStore,
      );

  Future<WeblinkImageSchemaDefinition> ensureDefinition(int workspaceId) async {
    final weblink = await _weblinks.ensureDefinition(workspaceId);
    final image = await _images.ensureDefinition(workspaceId);

    final representative = await systemObjects.ensureRelationProperty(
      objectTypeId: weblink.objectType.id,
      name: representativeImageName,
      targetObjectTypeId: image.objectType.id,
      multiple: false,
    );
    final related = await systemObjects.ensureRelationProperty(
      objectTypeId: weblink.objectType.id,
      name: relatedImagesName,
      targetObjectTypeId: image.objectType.id,
      multiple: true,
    );

    _validate(
      property: representative,
      imageObjectTypeId: image.objectType.id,
      multiple: false,
    );
    _validate(
      property: related,
      imageObjectTypeId: image.objectType.id,
      multiple: true,
    );

    return WeblinkImageSchemaDefinition(
      weblinkObjectTypeId: weblink.objectType.id,
      imageObjectTypeId: image.objectType.id,
      representativeImageProperty: representative,
      relatedImagesProperty: related,
    );
  }

  void _validate({
    required ObjectPropertyDefinition property,
    required int imageObjectTypeId,
    required bool multiple,
  }) {
    if (!property.isRelation ||
        property.targetObjectTypeId != imageObjectTypeId ||
        property.allowsMultipleRelations != multiple) {
      throw StateError(
        '${property.name} must be a ${multiple ? 'multi' : 'single'} '
        'Relation targeting the system Image ObjectType.',
      );
    }
  }
}
