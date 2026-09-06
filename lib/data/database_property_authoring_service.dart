import '../domain/object_model.dart';
import 'object_store.dart';

/// Canonical schema-authoring boundary for generic Database Property creation.
///
/// Presentation may collect names, Property kinds, Relation targets, and
/// cardinality, but persistence stays here on top of [ObjectStore]. Relation
/// creation deliberately delegates to [ObjectStore.createRelationProperty] so
/// source/target workspace validation and system-schema mutability rules are not
/// reimplemented by Database/View widgets.
class DatabasePropertyAuthoringService {
  const DatabasePropertyAuthoringService(this.objectStore);

  final ObjectStore objectStore;

  /// Returns every ObjectType that can be shown by the Relation target picker.
  ///
  /// [AppObjectType.kind] lets presentation distinguish built-in primitives
  /// from user-owned custom ObjectTypes without consulting the system registry
  /// itself.
  Future<List<AppObjectType>> relationTargets({
    required int workspaceId,
  }) =>
      objectStore.listObjectTypes(workspaceId);

  Future<int> createProperty({
    required int objectTypeId,
    required String name,
    required ObjectPropertyType type,
    Map<String, dynamic> config = const <String, dynamic>{},
    int? relationTargetObjectTypeId,
    bool relationMultiple = true,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Property name must not be empty.');
    }

    if (type == ObjectPropertyType.objectRelation) {
      final targetObjectTypeId = relationTargetObjectTypeId;
      if (targetObjectTypeId == null) {
        throw ArgumentError.notNull('relationTargetObjectTypeId');
      }
      if (config.isNotEmpty) {
        throw ArgumentError.value(
          config,
          'config',
          'Relation metadata must be created through the canonical Relation schema API.',
        );
      }
      return objectStore.createRelationProperty(
        objectTypeId: objectTypeId,
        name: trimmedName,
        targetObjectTypeId: targetObjectTypeId,
        multiple: relationMultiple,
      );
    }

    if (relationTargetObjectTypeId != null) {
      throw ArgumentError.value(
        relationTargetObjectTypeId,
        'relationTargetObjectTypeId',
        'Only Relation Properties may declare a target ObjectType.',
      );
    }

    return objectStore.createProperty(
      objectTypeId: objectTypeId,
      name: trimmedName,
      type: type,
      config: config,
    );
  }
}
