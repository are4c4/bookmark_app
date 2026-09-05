import 'dart:io';

class PdfFileMetadata {
  const PdfFileMetadata({required this.title, this.authors = const []});

  final String title;
  final List<String> authors;
}

class PdfMetadataService {
  const PdfMetadataService();

  Future<PdfFileMetadata> read(String path) async {
    final fallback = _fileNameWithoutExtension(path);
    if (!Platform.isMacOS) return PdfFileMetadata(title: fallback);

    try {
      final result = await Process.run(
        '/usr/bin/mdls',
        ['-raw', '-name', 'kMDItemTitle', '-name', 'kMDItemAuthors', path],
        runInShell: false,
      );
      if (result.exitCode != 0) return PdfFileMetadata(title: fallback);
      final output = result.stdout.toString();
      final title = _parseTitle(output) ?? fallback;
      final authors = _parseAuthors(output);
      return PdfFileMetadata(title: title, authors: authors);
    } catch (error, stackTrace) {
      _debugMetadataReadFailure(error, stackTrace);
      return PdfFileMetadata(title: fallback);
    }
  }

  void _debugMetadataReadFailure(Object error, StackTrace stackTrace) {
    assert(() {
      // Keep fallback diagnostics useful without logging the user file path or
      // exception text, either of which may contain local file information.
      stderr.writeln(
        'PdfMetadataService: mdls read failed; using filename fallback '
        '(${error.runtimeType})',
      );
      stderr.writeln(stackTrace);
      return true;
    }());
  }

  String? _parseTitle(String output) {
    final quoted = RegExp(r'kMDItemTitle\s*=\s*"([^"]+)"').firstMatch(output);
    if (quoted != null) return quoted.group(1)?.trim();
    return null;
  }

  List<String> _parseAuthors(String output) {
    final block = RegExp(
      r'kMDItemAuthors\s*=\s*\((.*?)\)',
      dotAll: true,
    ).firstMatch(output)?.group(1);
    if (block == null) return const [];
    return RegExp(r'"([^"]+)"')
        .allMatches(block)
        .map((m) => m.group(1)?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .toList();
  }

  String _fileNameWithoutExtension(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.substring(normalized.lastIndexOf('/') + 1);
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}
