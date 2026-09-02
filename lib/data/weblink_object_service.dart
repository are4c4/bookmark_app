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
    final rawUrl = '$sourceValue'.trim();
    final uri = Uri.tryParse(rawUrl);
    if (rawUrl.isEmpty || uri == null || !uri.hasScheme) {
      throw ArgumentError.value(
        sourceValue,
        'sourceValue',
        'Weblink promotion requires an absolute URL.',
      );
    }
    final derivedTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : (uri.host.isNotEmpty ? uri.host : rawUrl);

    return _promotionPlanner.plan(
      sourceProperty: sourceProperty,
      sourceValue: rawUrl,
      targetObjectTypeId: target.objectType.id,
      targetObjectTitle: derivedTitle,
      relationPropertyName: relationPropertyName,
    );
  }
}
