import 'package:file_selector/file_selector.dart';

typedef VaultDirectoryPicker = Future<String?> Function();

class VaultDirectoryPickerService {
  const VaultDirectoryPickerService({this.directoryPicker});

  final VaultDirectoryPicker? directoryPicker;

  Future<String?> pickDirectory() async {
    final picker = directoryPicker;
    final selected = picker == null ? await getDirectoryPath() : await picker();
    final trimmed = selected?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String suggestedVaultName(String directoryPath) {
    final normalized = directoryPath.trim().replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    return segments.isEmpty ? 'New Vault' : segments.last;
  }
}
