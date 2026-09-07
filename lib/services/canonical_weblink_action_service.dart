import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/object_store.dart';
import '../data/system_object_store.dart';
import '../data/weblink_object_service.dart';
import '../domain/object_model.dart';

typedef CanonicalWeblinkOpenAction = Future<bool> Function(Uri uri);
typedef CanonicalWeblinkCopyAction = Future<bool> Function(String url);

class CanonicalWeblinkResource {
  const CanonicalWeblinkResource({
    required this.weblinkObjectId,
    required this.url,
    required this.uri,
  });

  final int weblinkObjectId;
  final String url;
  final Uri uri;
}

/// Read-only URL resolver for the canonical built-in Weblink primitive.
///
/// The system ObjectType identity is verified before any structural URL lookup,
/// so a custom ObjectType with a URL-shaped Property never inherits Weblink
/// native actions implicitly. Resolving does not ensure schema or mutate the
/// Object; malformed/missing historical URL data simply fails closed.
class CanonicalWeblinkResourceResolver {
  const CanonicalWeblinkResourceResolver({
    required ObjectStore objectStore,
    required SystemObjectStore systemObjects,
  })  : _objectStore = objectStore,
        _systemObjects = systemObjects;

  final ObjectStore _objectStore;
  final SystemObjectStore _systemObjects;

  Future<CanonicalWeblinkResource?> resolve({
    required int weblinkObjectTypeId,
    required int weblinkObjectId,
  }) async {
    if (weblinkObjectTypeId <= 0 || weblinkObjectId <= 0) return null;
    final systemKey = await _systemObjects.systemKeyForObjectType(
      weblinkObjectTypeId,
    );
    if (systemKey != WeblinkObjectService.systemKey) return null;

    final type = await _objectStore.getObjectType(weblinkObjectTypeId);
    if (type == null) return null;
    final urlProperty = _uniqueProperty(type, 'URL');
    if (urlProperty == null || urlProperty.type != ObjectPropertyType.url) {
      return null;
    }

    final objects = await _objectStore.listObjects(weblinkObjectTypeId);
    AppObject? object;
    for (final candidate in objects) {
      if (candidate.id == weblinkObjectId) {
        object = candidate;
        break;
      }
    }
    if (object == null) return null;

    final url = '${object.values[urlProperty.id] ?? ''}'.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !_isWebUri(uri)) return null;
    return CanonicalWeblinkResource(
      weblinkObjectId: object.id,
      url: url,
      uri: uri,
    );
  }

  ObjectPropertyDefinition? _uniqueProperty(AppObjectType type, String name) {
    final matches = type.properties
        .where((property) => property.name == name)
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  bool _isWebUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return (scheme == 'http' || scheme == 'https') &&
        uri.hasAuthority &&
        uri.host.isNotEmpty;
  }
}

/// Native open/copy actions for one canonical Weblink Object.
///
/// The resolver owns identity validation; this service only delegates the final
/// external application / clipboard action. It never rewrites URL identity or
/// Weblink metadata, and failures expose stable messages without the user URL.
class CanonicalWeblinkActionService {
  CanonicalWeblinkActionService({
    required CanonicalWeblinkResourceResolver resources,
    CanonicalWeblinkOpenAction? openUrl,
    CanonicalWeblinkCopyAction? copyUrl,
  })  : _resources = resources,
        _openUrl = openUrl ?? _defaultOpenUrl,
        _copyUrl = copyUrl ?? _defaultCopyUrl;

  final CanonicalWeblinkResourceResolver _resources;
  final CanonicalWeblinkOpenAction _openUrl;
  final CanonicalWeblinkCopyAction _copyUrl;

  Future<void> open({
    required int weblinkObjectTypeId,
    required int weblinkObjectId,
  }) async {
    final resource = await _requiredResource(
      weblinkObjectTypeId: weblinkObjectTypeId,
      weblinkObjectId: weblinkObjectId,
    );
    if (!await _openUrl(resource.uri)) {
      throw const CanonicalWeblinkActionException(
        'Weblinkを開けませんでした。',
      );
    }
  }

  Future<void> copy({
    required int weblinkObjectTypeId,
    required int weblinkObjectId,
  }) async {
    final resource = await _requiredResource(
      weblinkObjectTypeId: weblinkObjectTypeId,
      weblinkObjectId: weblinkObjectId,
    );
    if (!await _copyUrl(resource.url)) {
      throw const CanonicalWeblinkActionException(
        'WeblinkのURLをコピーできませんでした。',
      );
    }
  }

  Future<CanonicalWeblinkResource> _requiredResource({
    required int weblinkObjectTypeId,
    required int weblinkObjectId,
  }) async {
    final resource = await _resources.resolve(
      weblinkObjectTypeId: weblinkObjectTypeId,
      weblinkObjectId: weblinkObjectId,
    );
    if (resource == null) {
      throw const CanonicalWeblinkUnavailableException();
    }
    return resource;
  }

  static Future<bool> _defaultOpenUrl(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _defaultCopyUrl(String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      return true;
    } catch (_) {
      return false;
    }
  }
}

class CanonicalWeblinkUnavailableException implements Exception {
  const CanonicalWeblinkUnavailableException();

  @override
  String toString() => 'WeblinkのURLが見つからないか、現在利用できません。';
}

class CanonicalWeblinkActionException implements Exception {
  const CanonicalWeblinkActionException(this.message);

  final String message;

  @override
  String toString() => message;
}
