import 'package:bookmark_app/services/vault_directory_picker_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pickDirectory returns the selected trimmed folder', () async {
    const selected = '/Users/example/Documents/My Vault';
    final service = VaultDirectoryPickerService(
      directoryPicker: () async => '  $selected  ',
    );

    expect(await service.pickDirectory(), selected);
  });

  test('pickDirectory treats cancellation and blank results as no selection',
      () async {
    final cancelled = VaultDirectoryPickerService(
      directoryPicker: () async => null,
    );
    final blank = VaultDirectoryPickerService(
      directoryPicker: () async => '   ',
    );

    expect(await cancelled.pickDirectory(), isNull);
    expect(await blank.pickDirectory(), isNull);
  });

  test('suggestedVaultName uses the selected folder name across separators', () {
    const service = VaultDirectoryPickerService();

    expect(
      service.suggestedVaultName('/Users/example/Documents/My Vault/'),
      'My Vault',
    );
    expect(
      service.suggestedVaultName(r'C:\Users\example\Portable Vault'),
      'Portable Vault',
    );
    expect(service.suggestedVaultName('/'), 'New Vault');
  });
}
