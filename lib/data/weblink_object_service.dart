import '../domain/object_model.dart';
import '../domain/object_type_defaults.dart';
import '../domain/object_value_promotion.dart';
import 'object_type_defaults_store.dart';
import 'system_object_store.dart';

class WeblinkObjectDefinition {
  const WeblinkObjectDefinition({
    required this.objectType,
    required this.urlProperty,
    required this.domainProperty,
    required this.pageTitleProperty,
    required this.descriptionProperty,
    required this.previewImageUrlProperty,
  });

  final AppObjectType objectType;
  final ObjectPropertyDefinition urlProperty;
  final ObjectPropertyDefinition domainProperty;
  final ObjectPropertyDefinition pageTitleProperty;
  final ObjectPropertyDefinition descriptionProperty;
  final ObjectPropertyDefinition previewImageUrlProperty;
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
    final domainProperty = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Domain',
      type: ObjectPropertyType.text,
    );
    final pageTitleProperty = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Page title',
      type: ObjectPropertyType.text,
    );
    final descriptionProperty = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Description',
      type: ObjectPropertyType.text,
    );
    final previewImageUrlProperty = await systemObjects.ensureProperty(
      objectTypeId: type.id,
      name: 'Preview image URL',
      type: ObjectPropertyType.url,
    );
    type = (await systemObjects.getSystemObjectType(
      workspaceId: workspaceId,
      systemKey: systemKey,
    ))!;

    await _ensureDefaults(
      objectTypeId: type.id,
      urlProperty: urlProperty,
      domainProperty: domainProperty,
      pageTitleProperty: pageTitleProperty,
      descriptionProperty: descriptionProperty,
      previewImageUrlProperty: previewImageUrlProperty,
    );

    return WeblinkObjectDefinition(
      objectType: type,
      urlProperty: urlProperty,
      domainProperty: domainProperty,
      pageTitleProperty: pageTitleProperty,
      descriptionProperty: descriptionProperty,
      previewImageUrlProperty: previewImageUrlProperty,
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
        if (normalizeUrl(stored) == normalizedUrl) {
          await _setDomainIfMissing(
            object: object,
            definition: definition,
            normalizedUrl: normalizedUrl,
          );
          return await _reload(definition.objectType.id, object.id);
        }
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
    final created = await _reload(definition.objectType.id, objectId);
    await _setDomainIfMissing(
      object: created,
      definition: definition,
      normalizedUrl: normalizedUrl,
    );
    return _reload(definition.objectType.id, objectId);
  }

  /// Adds resource-derived metadata without overwriting metadata already owned
  /// by the reusable Weblink Object.
  ///
  /// This lets legacy Bookmark metadata seed a Weblink once while keeping later
  /// Bookmark-specific edits independent.
  Future<AppObject> enrichIfMissing({
    required int workspaceId,
    required int objectId,
    String? pageTitle,
    String? description,
    String? previewImageUrl,
  }) async {
    final definition = await ensureDefinition(workspaceId);
    final object = await _reload(definition.objectType.id, objectId);
    final rawUrl = '${object.values[definition.urlProperty.id] ?? ''}'.trim();
    if (rawUrl.isEmpty) {
      throw StateError('Weblink metadata enrichment requires a URL Value.');
    }
    final normalizedUrl = normalizeUrl(rawUrl);

    await _setDomainIfMissing(
      object: object,
      definition: definition,
      normalizedUrl: normalizedUrl,
    );
    await _setIfMissing(
      object: object,
      property: definition.pageTitleProperty,
      value: pageTitle,
    );
    await _setIfMissing(
      object: object,
      property: definition.descriptionProperty,
      value: description,
    );

    String? normalizedPreview;
    if (previewImageUrl?.trim().isNotEmpty == true) {
      try {
        normalizedPreview = normalizeUrl(previewImageUrl!);
      } on ArgumentError {
        normalizedPreview = null;
      }
    }
    await _setIfMissing(
      object: object,
      property: definition.previewImageUrlProperty,
      value: normalizedPreview,
    );
    return _reload(definition.objectType.id, objectId);
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

  Future<void> _ensureDefaults({
    required int objectTypeId,
    required ObjectPropertyDefinition urlProperty,
    required ObjectPropertyDefinition domainProperty,
    required ObjectPropertyDefinition pageTitleProperty,
    required ObjectPropertyDefinition descriptionProperty,
    required ObjectPropertyDefinition previewImageUrlProperty,
  }) async {
    final desiredVisible = <int>[
      pageTitleProperty.id,
      domainProperty.id,
      descriptionProperty.id,
      urlProperty.id,
    ];
    final desiredOrder = <int>[
      pageTitleProperty.id,
      domainProperty.id,
      descriptionProperty.id,
      urlProperty.id,
      previewImageUrlProperty.id,
    ];
    final previousVisible = <int>[
      urlProperty.id,
      domainProperty.id,
      pageTitleProperty.id,
      descriptionProperty.id,
    ];
    final previousOrder = <int>[
      urlProperty.id,
      domainProperty.id,
      pageTitleProperty.id,
      descriptionProperty.id,
      previewImageUrlProperty.id,
    ];
    final current = await defaultsStore.read(objectTypeId);
    if (current == null) {
      await defaultsStore.write(
        objectTypeId: objectTypeId,
        defaults: ObjectTypeDefaults(
          visiblePropertyIds: desiredVisible,
          propertyOrder: desiredOrder,
          openMode: ObjectOpenMode.sidePeek,
        ),
      );
      return;
    }

    // Upgrade only exact defaults written by earlier Weblink definitions.
    // Any user-customized visibility or ordering is preserved as-is.
    final upgradeVisible = current.visiblePropertyIds == null ||
        _sameIds(current.visiblePropertyIds!, <int>[urlProperty.id]) ||
        _sameIds(current.visiblePropertyIds!, previousVisible);
    final upgradeOrder = current.propertyOrder == null ||
        _sameIds(current.propertyOrder!, <int>[urlProperty.id]) ||
        _sameIds(current.propertyOrder!, previousOrder);
    final needsWrite =
        upgradeVisible || upgradeOrder || current.openMode == null;
    if (!needsWrite) return;

    await defaultsStore.write(
      objectTypeId: objectTypeId,
      defaults: ObjectTypeDefaults(
        visiblePropertyIds:
            upgradeVisible ? desiredVisible : current.visiblePropertyIds,
        propertyOrder: upgradeOrder ? desiredOrder : current.propertyOrder,
        openMode: current.openMode ?? ObjectOpenMode.sidePeek,
      ),
    );
  }

  bool _sameIds(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Future<void> _setDomainIfMissing({
    required AppObject object,
    required WeblinkObjectDefinition definition,
    required String normalizedUrl,
  }) async {
    final host = Uri.parse(normalizedUrl).host.trim();
    if (host.isEmpty) return;
    await _setIfMissing(
      object: object,
      property: definition.domainProperty,
      value: host,
    );
  }

  Future<void> _setIfMissing({
    required AppObject object,
    required ObjectPropertyDefinition property,
    required String? value,
  }) async {
    final candidate = value?.trim();
    if (candidate == null || candidate.isEmpty) return;
    final current = '${object.values[property.id] ?? ''}'.trim();
    if (current.isNotEmpty) return;
    await systemObjects.objectStore.setPropertyValue(
      objectId: object.id,
      property: property,
      value: candidate,
    );
  }

  Future<AppObject> _reload(int objectTypeId, int objectId) async {
    final objects = await systemObjects.objectStore.listObjects(objectTypeId);
    for (final object in objects) {
      if (object.id == objectId) return object;
    }
    throw StateError('Weblink Object $objectId does not exist.');
  }
}