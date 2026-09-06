import '../domain/object_model.dart';
import '../domain/object_type_defaults.dart';
import 'generic_database_store.dart';
import 'object_store.dart';
import 'object_type_defaults_store.dart';

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

    final defaultsStore = ObjectTypeDefaultsStore(genericStore);
    final sourceDefaults = await defaultsStore.read(source.id);

    return genericStore.database.transaction(() async {
      final duplicatedId = await objectStore.createObjectType(
        workspaceId: source.workspaceId,
        name: name?.trim().isNotEmpty == true ? name!.trim() : '${source.name} のコピー',
        icon: icon?.trim().isNotEmpty == true ? icon!.trim() : source.icon,
      );
      final duplicatedPropertyIds = <int, int>{};

      // Preserve canonical schema order. Splitting Value and Relation Properties
      // into separate loops changes the copied ObjectType whenever the source
      // interleaves those semantics.
      for (final property in source.properties) {
        if (!property.isRelation) {
          final duplicatedPropertyId = await objectStore.createProperty(
            objectTypeId: duplicatedId,
            name: property.name,
            type: property.type,
            config: Map<String, dynamic>.from(property.config),
          );
          duplicatedPropertyIds[property.id] = duplicatedPropertyId;
          continue;
        }

        final sourceTargetId = property.targetObjectTypeId;
        if (sourceTargetId == null) {
          throw StateError(
            'Relation Property ${property.id} is missing target ObjectType metadata.',
          );
        }
        final duplicatedTargetId = sourceTargetId == source.id
            ? duplicatedId
            : sourceTargetId;
        final metadata = Map<String, dynamic>.from(property.config)
          ..remove('targetObjectTypeId')
          ..remove('multiple')
          ..remove('inversePropertyId')
          ..remove('bidirectional')
          ..remove('pairRole');
        final duplicatedPropertyId = await objectStore.createRelationProperty(
          objectTypeId: duplicatedId,
          name: property.name,
          targetObjectTypeId: duplicatedTargetId,
          multiple: property.allowsMultipleRelations,
          metadata: metadata,
        );
        duplicatedPropertyIds[property.id] = duplicatedPropertyId;
      }

      // Formula and Rollup configs persist Property ids. They can only be
      // rewritten after every duplicated Property id is known, so create the
      // schema in source order first and then patch computed configs inside the
      // same transaction before the duplicate becomes visible.
      final duplicatedProperties = await genericStore.listProperties(duplicatedId);
      final duplicatedPropertiesById = <int, GenericPropertyRecord>{
        for (final property in duplicatedProperties) property.id: property,
      };
      for (final property in source.properties.where((item) => item.isComputed)) {
        final duplicatedPropertyId = duplicatedPropertyIds[property.id];
        final duplicatedProperty = duplicatedPropertyId == null
            ? null
            : duplicatedPropertiesById[duplicatedPropertyId];
        if (duplicatedProperty == null) {
          throw StateError(
            'Computed Property ${property.id} was not duplicated.',
          );
        }
        await genericStore.updateProperty(
          GenericPropertyRecord(
            id: duplicatedProperty.id,
            databaseId: duplicatedProperty.databaseId,
            name: duplicatedProperty.name,
            type: duplicatedProperty.type,
            sortOrder: duplicatedProperty.sortOrder,
            config: await _remapComputedConfig(
              source: source,
              property: property,
              duplicatedPropertyIds: duplicatedPropertyIds,
            ),
          ),
        );
      }

      if (sourceDefaults != null) {
        List<int>? remapPropertyIds(List<int>? ids) => ids
            ?.map((id) => duplicatedPropertyIds[id])
            .whereType<int>()
            .toList(growable: false);

        await defaultsStore.write(
          objectTypeId: duplicatedId,
          defaults: ObjectTypeDefaults(
            visiblePropertyIds:
                remapPropertyIds(sourceDefaults.visiblePropertyIds),
            propertyOrder: remapPropertyIds(sourceDefaults.propertyOrder),
            openMode: sourceDefaults.openMode,
            bodyTemplate: sourceDefaults.bodyTemplate,
          ),
        );
      }
      return duplicatedId;
    });
  }

  Future<Map<String, dynamic>> _remapComputedConfig({
    required AppObjectType source,
    required ObjectPropertyDefinition property,
    required Map<int, int> duplicatedPropertyIds,
  }) async {
    final config = Map<String, dynamic>.from(property.config);
    switch (property.type) {
      case ObjectPropertyType.formula:
        final expression = '${config['expression'] ?? ''}';
        config['expression'] = expression.replaceAllMapped(
          RegExp(r'\{\s*(\d+)\s*\}'),
          (match) {
            final sourcePropertyId = int.parse(match.group(1)!);
            final duplicatedPropertyId =
                duplicatedPropertyIds[sourcePropertyId];
            if (duplicatedPropertyId == null) {
              throw StateError(
                'Formula Property ${property.id} references Property '
                '$sourcePropertyId outside the duplicated ObjectType.',
              );
            }
            return '{$duplicatedPropertyId}';
          },
        );
        return config;
      case ObjectPropertyType.rollup:
        final sourceRelationPropertyId =
            _configInt(config['relationPropertyId']);
        if (sourceRelationPropertyId == null) {
          throw StateError(
            'Rollup Property ${property.id} is missing relationPropertyId.',
          );
        }
        final duplicatedRelationPropertyId =
            duplicatedPropertyIds[sourceRelationPropertyId];
        ObjectPropertyDefinition? sourceRelationProperty;
        for (final candidate in source.properties) {
          if (candidate.id == sourceRelationPropertyId) {
            sourceRelationProperty = candidate;
            break;
          }
        }
        if (duplicatedRelationPropertyId == null ||
            sourceRelationProperty == null ||
            !sourceRelationProperty.isRelation) {
          throw StateError(
            'Rollup Property ${property.id} references an invalid Relation '
            'Property $sourceRelationPropertyId.',
          );
        }
        config['relationPropertyId'] = duplicatedRelationPropertyId;

        final aggregation = '${config['aggregation'] ?? 'count'}';
        if (aggregation != 'count' && !config.containsKey('targetPropertyId')) {
          throw StateError(
            'Rollup Property ${property.id} requires targetPropertyId for '
            '$aggregation.',
          );
        }

        if (config.containsKey('targetPropertyId')) {
          final sourceTargetPropertyId = _configInt(config['targetPropertyId']);
          if (sourceTargetPropertyId == null) {
            throw StateError(
              'Rollup Property ${property.id} has an invalid targetPropertyId.',
            );
          }
          if (sourceRelationProperty.targetObjectTypeId == source.id) {
            final duplicatedTargetPropertyId =
                duplicatedPropertyIds[sourceTargetPropertyId];
            if (duplicatedTargetPropertyId == null) {
              throw StateError(
                'Rollup Property ${property.id} references Property '
                '$sourceTargetPropertyId outside the duplicated self target.',
              );
            }
            if (aggregation != 'count') {
              final sourceTargetProperty = source.properties
                  .where((candidate) => candidate.id == sourceTargetPropertyId)
                  .firstOrNull;
              if (!_isNumericRollupTarget(sourceTargetProperty)) {
                throw StateError(
                  'Rollup Property ${property.id} requires a numeric target '
                  'Property.',
                );
              }
            }
            config['targetPropertyId'] = duplicatedTargetPropertyId;
          } else {
            // The Relation still targets the original external ObjectType, so
            // its target Property identity remains canonical and unchanged.
            if (aggregation != 'count') {
              final targetTypeId = sourceRelationProperty.targetObjectTypeId;
              final targetType = targetTypeId == null
                  ? null
                  : await objectStore.getObjectType(targetTypeId);
              final targetProperty = targetType?.properties
                  .where((candidate) => candidate.id == sourceTargetPropertyId)
                  .firstOrNull;
              if (!_isNumericRollupTarget(targetProperty)) {
                throw StateError(
                  'Rollup Property ${property.id} requires a numeric target '
                  'Property on its Relation target ObjectType.',
                );
              }
            }
            config['targetPropertyId'] = sourceTargetPropertyId;
          }
        }
        return config;
      default:
        return config;
    }
  }

  bool _isNumericRollupTarget(ObjectPropertyDefinition? property) =>
      property != null &&
      (property.type == ObjectPropertyType.number ||
          property.type == ObjectPropertyType.rating);

  int? _configInt(dynamic value) =>
      value is int ? value : int.tryParse('${value ?? ''}');

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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
