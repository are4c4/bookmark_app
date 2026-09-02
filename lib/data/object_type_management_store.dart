import '../domain/object_model.dart';
import 'generic_database_store.dart';
import 'object_store.dart';

class ObjectTypeManagementStore {
  ObjectTypeManagementStore({
    required this.genericStore,
    required this.objectStore,
  });

  final GenericDatabaseStore genericStore;
  final ObjectStore objectStore;

  Future<int> duplicateSchema({
    required int objectTypeId,
    String? name,
    String? icon,
  }) async {
    final source = await objectStore.getObjectType(objectTypeId);
    if (source == null) {
      throw ArgumentError.value(objectTypeId, 'objectTypeId', 'ObjectType does not exist.');
    }
    if (source.kind == ObjectTypeKind.system) {
      throw StateError('System ObjectTypes cannot be duplicated as managed schemas.');
    }

    return genericStore.database.transaction(() async {
      final duplicatedId = await objectStore.createObjectType(
        workspaceId: source.workspaceId,
        name: name?.trim().isNotEmpty == true ? name!.trim() : '${source.name} のコピー',
        icon: icon?.trim().isNotEmpty == true ? icon!.trim() : source.icon,
      );

      for (final property in source.properties.where((item) => !item.isRelation)) {
        await objectStore.createProperty(
          objectTypeId: duplicatedId,
          name: property.name,
          type: property.type,
          config: Map<String, dynamic>.from(property.config),
        );
      }
      for (final property in source.properties.where((item) => item.isRelation)) {
        final sourceTargetId = property.targetObjectTypeId;
        if (sourceTargetId == null) continue;
        final duplicatedTargetId = sourceTargetId == source.id
            ? duplicatedId
            : sourceTargetId;
        final config = Map<String, dynamic>.from(property.config)
          ..['targetObjectTypeId'] = duplicatedTargetId
          ..remove('inversePropertyId')
          ..remove('bidirectional')
          ..remove('pairRole');
        await objectStore.createProperty(
          objectTypeId: duplicatedId,
          name: property.name,
          type: ObjectPropertyType.objectRelation,
          config: config,
        );
      }
      return duplicatedId;
    });
  }

  Future<void> updateIdentity({
    required int objectTypeId,
    String? name,
    String? icon,
  }) async {
    final type = await objectStore.getObjectType(objectTypeId);
    if (type == null) {
      throw ArgumentError.value(objectTypeId, 'objectTypeId', 'ObjectType does not exist.');
    }
    if (type.kind == ObjectTypeKind.system) {
      throw StateError('System ObjectType identity is managed by the application.');
    }
    await genericStore.database.transaction(() async {
      if (name?.trim().isNotEmpty == true) {
        await objectStore.renameObjectType(objectTypeId, name!.trim());
      }
      if (icon?.trim().isNotEmpty == true) {
        await genericStore.setDatabaseIcon(objectTypeId, icon!.trim());
      }
    });
  }

  Future<void> deleteCustomType(int objectTypeId) async {
    final type = await objectStore.getObjectType(objectTypeId);
    if (type == null) return;
    if (type.kind == ObjectTypeKind.system) {
      throw StateError('System ObjectTypes cannot be deleted.');
    }
    await objectStore.deleteObjectType(objectTypeId);
  }
}
