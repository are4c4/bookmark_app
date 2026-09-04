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
  /// Object; Relation writes remain owned by the canonical Relation boundary.
  Future<AppObject> findOrCreate({
    required int workspaceId,
    required String url,
    String? title,
  }) async {
    final normalizedUrl = normalizeUrl(url);
    final definition = await ensureDefinition(workspaceId);
    final objects = await systemObjects.objectStore.listObjects(
      definition.objectType.id,
    );
    for (final object in objects) {
      final stored = '${object.values[definition.urlProperty.id] ?? ''}'.trim();
      if (stored.isEmpty) continue;
      try {
        if (normalizeUrl(stored) == normalizedUrl) return object;
      } on ArgumentError {
        // Ignore malformed pre-existing values instead of making valid Weblink
        // creation depend on unrelated legacy corruption.
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
    final normalizedUrl = normalizeUrl('$sourceValue');
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

  /// Canonicalizes only URI components whose equivalence is well-defined.
  ///
  /// Query and fragment content are deliberately preserved because changing
  /// either can change the user-visible resource. HTTP(S) host/scheme casing,
  /// default ports, dot path segments, and an empty root path are normalized.
  String normalizeUrl(String value) {
    final rawUrl = value.trim();
    final parsed = Uri.tryParse(rawUrl);
    if (rawUrl.isEmpty || parsed == null || !parsed.hasScheme) {
      throw ArgumentError.value(
        value,
        'url',
        'Weblink requires an absolute URL.',
      );
    }

    final uri = parsed.normalizePath();
    final scheme = uri.scheme.toLowerCase();
    if (!uri.hasAuthority || uri.host.isEmpty) {
      return uri.replace(scheme: scheme).toString();
    }

    final host = uri.host.toLowerCase();
    final defaultPort = uri.hasPort &&
        ((scheme == 'http' && uri.port == 80) ||
            (scheme == 'https' && uri.port == 443));
    final authority = StringBuffer();
    if (uri.userInfo.isNotEmpty) {
      authority
        ..write(uri.userInfo)
        ..write('@');
    }
    if (host.contains(':')) {
      authority
        ..write('[')
        ..write(host)
        ..write(']');
    } else {
      authority.write(host);
    }
    if (uri.hasPort && !defaultPort) {
      authority
        ..write(':')
        ..write(uri.port);
    }

    final path = uri.path.isEmpty && (scheme == 'http' || scheme == 'https')
        ? '/'
        : uri.path;
    final query = uri.hasQuery ? '?${uri.query}' : '';
    final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
    return '$scheme://${authority.toString()}$path$query$fragment';
  }
}
