import '../domain/object_model.dart';
import '../domain/object_type_defaults.dart';
import '../domain/object_value_promotion.dart';
import 'object_type_defaults_store.dart';
import 'system_object_store.dart';

class WeblinkObjectDefinition {
  const WeblinkObjectDefinition({
    required this.objectType,
    required this.urlProperty,
  });

  final AppObjectType objectType;
  final ObjectPropertyDefinition urlProperty;
}

/// Defines Weblink as a reusable first-class Object without replacing legacy
/// bookmark storage. URL values can opt into promotion only when the user wants
/// independent identity, metadata, navigation, or Relations.
class WeblinkObjectService {
  WeblinkObjectService({
    required this.systemObjects,
    required this.defaultsStore,
  });

  static const String systemKey = 'weblink';

  final SystemObjectStore systemObjects;
  final ObjectTypeDefaultsStore defaultsStore;
  final ObjectValuePromotionPlanner _promotionPlanner =
      const ObjectValuePromotionPlanner();

  Future<WeblinkObjectDefinition> ensureDefinition(int workspaceId) async {
    var type = await systemObjects.ensureSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
      name: 'Weblink',
      icon: '🔗',
    );
    final urlProperty = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'URL',
      type: ObjectPropertyType.url,
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
          visiblePropertyIds: <int>[urlProperty.id],
          propertyOrder: <int>[urlProperty.id],
          openMode: ObjectOpenMode.sidePeek,
        ),
      );
    }

    return WeblinkObjectDefinition(
      objectType: type,
      urlProperty: urlProperty,
    );
  }

  /// Returns an existing Weblink for the normalized URL when possible.
  ///
  /// This is intentionally separate from creating a Relation from a source
  /// Object; the Relation lane owns write-integrity rules for that later step.
  Future<AppObject> findOrCreate({
    required int workspaceId,
    required String url,
    String? title,
  }) async {
    final normalizedUrl = _normalizeUrl(url);
    final definition = await ensureDefinition(workspaceId);
    final objects = await systemObjects.objectStore.listObjects(
      definition.objectType.id,
    );
    for (final object in objects) {
      if ('${object.values[definition.urlProperty.id] ?? ''}'.trim() ==
          normalizedUrl) {
        return object;
      }
    }

    final uri = Uri.parse(normalizedUrl);
    final derivedTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : (uri.host.isNotEmpty ? uri.host : normalizedUrl);
    final objectId = await systemObjects.objectStore.createObject(
      objectTypeId: definition.objectType.id,
      title: derivedTitle,
    );
    await systemObjects.objectStore.setPropertyValue(
      objectId: objectId,
      property: definition.urlProperty,
      value: normalizedUrl,
    );
    return (await systemObjects.objectStore.listObjects(definition.objectType.id))
        .singleWhere((object) => object.id == objectId);
  }

  ObjectValuePromotionPlan planUrlPromotion({
    required ObjectPropertyDefinition sourceProperty,
    required dynamic sourceValue,
    required WeblinkObjectDefinition target,
    String relationPropertyName = 'Weblink',
    String? title,
  }) {
    if (sourceProperty.type != ObjectPropertyType.url) {
      throw ArgumentError.value(
        sourceProperty.type,
        'sourceProperty',
        'Weblink promotion requires a URL Value property.',
      );
    }
    final normalizedUrl = _normalizeUrl('$sourceValue');
    final uri = Uri.parse(normalizedUrl);
    final derivedTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : (uri.host.isNotEmpty ? uri.host : normalizedUrl);

    return _promotionPlanner.plan(
      sourceProperty: sourceProperty,
      sourceValue: normalizedUrl,
      targetObjectTypeId: target.objectType.id,
      targetObjectTitle: derivedTitle,
      relationPropertyName: relationPropertyName,
    );
  }

  String _normalizeUrl(String value) {
    final rawUrl = value.trim();
    final uri = Uri.tryParse(rawUrl);
    if (rawUrl.isEmpty || uri == null || !uri.hasScheme) {
      throw ArgumentError.value(
        value,
        'url',
        'Weblink requires an absolute URL.',
      );
    }
    return uri.toString();
  }
}
