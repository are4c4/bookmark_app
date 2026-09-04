import 'package:http/http.dart' as http;

import 'photo_storage_service.dart';

class ManagedRemoteImage {
  const ManagedRemoteImage({
    required this.path,
    required this.sourceUrl,
    required this.originalName,
    required this.contentType,
  });

  final String path;
  final String sourceUrl;
  final String originalName;
  final String contentType;
}

/// Downloads optional Weblink preview images into app-managed photo storage.
///
/// HTTP/content failures return null so metadata enrichment cannot block the
/// canonical Weblink/Bookmark workflow. Invalid caller URLs still fail fast.
class RemoteImageStorageService {
  RemoteImageStorageService({
    http.Client? client,
    PhotoStorageService? storage,
  })  : _client = client,
        _storage = storage ?? const PhotoStorageService();

  final http.Client? _client;
  final PhotoStorageService _storage;

  Future<ManagedRemoteImage?> download(String sourceUrl) async {
    final rawUrl = sourceUrl.trim();
    final uri = Uri.tryParse(rawUrl);
    if (rawUrl.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError.value(
        sourceUrl,
        'sourceUrl',
        'Remote image requires an absolute HTTP(S) URL.',
      );
    }

    final ownedClient = _client == null ? http.Client() : null;
    final client = _client ?? ownedClient!;
    try {
      final response = await client
          .get(
            uri,
            headers: const <String, String>{
              'User-Agent':
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                  'AppleWebKit/537.36 bookmark_app/0.1',
              'Accept': 'image/*',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final contentType = _normalizedContentType(
        response.headers['content-type'],
      );
      final extension = _extensionFor(contentType);
      if (extension == null || response.bodyBytes.isEmpty) return null;

      final originalName = _originalName(uri, extension);
      final imported = await _storage.importBytes(
        bytes: response.bodyBytes,
        originalName: originalName,
      );
      return ManagedRemoteImage(
        path: imported.path,
        sourceUrl: uri.toString(),
        originalName: imported.originalName,
        contentType: contentType,
      );
    } on ArgumentError {
      rethrow;
    } catch (_) {
      return null;
    } finally {
      ownedClient?.close();
    }
  }

  String _normalizedContentType(String? header) {
    return (header ?? '').split(';').first.trim().toLowerCase();
  }

  String? _extensionFor(String contentType) {
    switch (contentType) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/heic':
        return 'heic';
      case 'image/heif':
        return 'heif';
      default:
        return null;
    }
  }

  String _originalName(Uri uri, String extension) {
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last.trim();
    if (segment.isNotEmpty && _hasSupportedExtension(segment)) return segment;
    return 'remote_image.$extension';
  }

  bool _hasSupportedExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return false;
    return const <String>{
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'heic',
      'heif',
    }.contains(name.substring(dot + 1).toLowerCase());
  }
}
