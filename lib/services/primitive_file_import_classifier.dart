import 'dart:io';

enum PrimitiveFileImportTarget { image, file }

enum PrimitiveFileImportEvidence { content, mime, extension, fallback }

class PrimitiveFileImportClassification {
  const PrimitiveFileImportClassification({
    required this.target,
    required this.evidence,
    this.contentType,
  });

  final PrimitiveFileImportTarget target;
  final PrimitiveFileImportEvidence evidence;
  final String? contentType;
}

/// Owns the Image-vs-File primitive routing decision for imported files.
///
/// Strong content signatures win over caller-provided MIME and filename
/// extension. A meaningful MIME wins over the extension. Extensions are only a
/// conservative fallback when neither content nor MIME identifies the format.
/// Unknown/unsupported formats remain generic File Objects.
class PrimitiveFileImportClassifier {
  const PrimitiveFileImportClassifier();

  static const int probeByteCount = 32;

  static const Set<String> _supportedImageContentTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/heic',
    'image/heif',
  };

  static const Set<String> _supportedImageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
  };

  Future<PrimitiveFileImportClassification> classifyPath({
    required String path,
    String? declaredContentType,
  }) async {
    final filename = _fileName(path);
    var header = const <int>[];
    try {
      final file = await File(path).open();
      try {
        header = await file.read(probeByteCount);
      } finally {
        await file.close();
      }
    } on FileSystemException {
      // Classification remains deterministic from MIME/extension when content
      // cannot be probed. Do not log the path or exception text.
    }
    return classify(
      filename: filename,
      declaredContentType: declaredContentType,
      headerBytes: header,
    );
  }

  PrimitiveFileImportClassification classify({
    required String filename,
    String? declaredContentType,
    List<int> headerBytes = const <int>[],
  }) {
    final detected = _contentTypeFromHeader(headerBytes);
    if (detected != null) {
      return PrimitiveFileImportClassification(
        target: _targetForContentType(detected),
        evidence: PrimitiveFileImportEvidence.content,
        contentType: detected,
      );
    }

    final declared = _normalizeContentType(declaredContentType);
    if (declared != null && !_isGenericBinaryMime(declared)) {
      return PrimitiveFileImportClassification(
        target: _targetForContentType(declared),
        evidence: PrimitiveFileImportEvidence.mime,
        contentType: declared,
      );
    }

    final extension = _extension(filename);
    if (extension != null && _supportedImageExtensions.contains(extension)) {
      return PrimitiveFileImportClassification(
        target: PrimitiveFileImportTarget.image,
        evidence: PrimitiveFileImportEvidence.extension,
        contentType: _contentTypeForImageExtension(extension),
      );
    }

    return PrimitiveFileImportClassification(
      target: PrimitiveFileImportTarget.file,
      evidence: PrimitiveFileImportEvidence.fallback,
      contentType: declared,
    );
  }

  PrimitiveFileImportTarget _targetForContentType(String contentType) =>
      _supportedImageContentTypes.contains(contentType)
          ? PrimitiveFileImportTarget.image
          : PrimitiveFileImportTarget.file;

  String? _contentTypeFromHeader(List<int> bytes) {
    if (_startsWith(
      bytes,
      const <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    )) {
      return 'image/png';
    }
    if (_startsWith(bytes, const <int>[0xff, 0xd8, 0xff])) {
      return 'image/jpeg';
    }
    if (_asciiAt(bytes, 0, 'GIF87a') || _asciiAt(bytes, 0, 'GIF89a')) {
      return 'image/gif';
    }
    if (_startsWith(bytes, const <int>[0x42, 0x4d])) return 'image/bmp';
    if (_startsWith(bytes, const <int>[0x49, 0x49, 0x2a, 0x00]) ||
        _startsWith(bytes, const <int>[0x4d, 0x4d, 0x00, 0x2a])) {
      return 'image/tiff';
    }
    if (_startsWith(bytes, const <int>[0x00, 0x00, 0x01, 0x00])) {
      return 'image/x-icon';
    }
    if (_asciiAt(bytes, 0, 'RIFF')) {
      if (_asciiAt(bytes, 8, 'WEBP')) return 'image/webp';
      if (_asciiAt(bytes, 8, 'WAVE')) return 'audio/wav';
      if (_asciiAt(bytes, 8, 'AVI ')) return 'video/x-msvideo';
    }
    if (_asciiAt(bytes, 0, '%PDF-')) return 'application/pdf';
    if (_startsWith(bytes, const <int>[0x50, 0x4b, 0x03, 0x04]) ||
        _startsWith(bytes, const <int>[0x50, 0x4b, 0x05, 0x06]) ||
        _startsWith(bytes, const <int>[0x50, 0x4b, 0x07, 0x08])) {
      return 'application/zip';
    }
    if (_startsWith(bytes, const <int>[0x1f, 0x8b])) {
      return 'application/gzip';
    }
    if (_startsWith(
      bytes,
      const <int>[0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c],
    )) {
      return 'application/x-7z-compressed';
    }
    if (_startsWith(bytes, const <int>[0x52, 0x61, 0x72, 0x21, 0x1a, 0x07])) {
      return 'application/vnd.rar';
    }
    if (_asciiAt(bytes, 0, 'OggS')) return 'application/ogg';
    if (_asciiAt(bytes, 0, 'fLaC')) return 'audio/flac';
    if (_asciiAt(bytes, 0, 'ID3')) return 'audio/mpeg';
    if (_asciiAt(bytes, 4, 'ftyp') && bytes.length >= 12) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
      if (<String>{'heic', 'heix', 'hevc', 'hevx'}.contains(brand)) {
        return 'image/heic';
      }
      if (<String>{'heif', 'mif1', 'msf1'}.contains(brand)) {
        return 'image/heif';
      }
      if (<String>{'avif', 'avis'}.contains(brand)) return 'image/avif';
      if (<String>{
        'isom',
        'iso2',
        'mp41',
        'mp42',
        'avc1',
        'dash',
      }.contains(brand)) {
        return 'video/mp4';
      }
      if (brand == 'qt  ') return 'video/quicktime';
      if (brand == 'm4v ') return 'video/x-m4v';
      if (brand == 'm4a ') return 'audio/mp4';
      if (<String>{'3gp4', '3gp5', '3ge6', '3gg6'}.contains(brand)) {
        return 'video/3gpp';
      }
    }
    return null;
  }

  bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }
    return true;
  }

  bool _asciiAt(List<int> bytes, int offset, String expected) {
    if (offset < 0 || bytes.length < offset + expected.length) return false;
    for (var index = 0; index < expected.length; index++) {
      if (bytes[offset + index] != expected.codeUnitAt(index)) return false;
    }
    return true;
  }

  String? _normalizeContentType(String? value) {
    final candidate = value?.trim().toLowerCase();
    if (candidate == null || candidate.isEmpty) return null;
    final separator = candidate.indexOf(';');
    final mime = separator < 0
        ? candidate
        : candidate.substring(0, separator).trim();
    if (!_mimeTypePattern.hasMatch(mime)) return null;
    return mime;
  }

  static final RegExp _mimeTypePattern = RegExp(
    r"^[a-z0-9!#$%&'*+.^_`|~-]+/[a-z0-9!#$%&'*+.^_`|~-]+$",
  );

  bool _isGenericBinaryMime(String value) =>
      value == 'application/octet-stream' || value == 'binary/octet-stream';

  String? _contentTypeForImageExtension(String extension) => switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _ => null,
      };

  String? _extension(String filename) {
    final name = _fileName(filename);
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  String _fileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }
}
