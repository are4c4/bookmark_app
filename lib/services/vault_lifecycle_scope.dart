import 'package:flutter/widgets.dart';

import 'profile_manager.dart';

class VaultLifecycleScope extends InheritedWidget {
  const VaultLifecycleScope({
    super.key,
    required this.profileState,
    required this.createVault,
    required this.openVault,
    required this.switchVault,
    this.moveVault,
    required super.child,
  });

  final ProfileState profileState;
  final Future<void> Function() createVault;
  final Future<void> Function() openVault;
  final Future<void> Function(DatabaseProfile profile) switchVault;
  final Future<void> Function()? moveVault;

  static VaultLifecycleScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VaultLifecycleScope>();

  static VaultLifecycleScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No VaultLifecycleScope found in context.');
    return scope!;
  }

  @override
  bool updateShouldNotify(VaultLifecycleScope oldWidget) =>
      profileState != oldWidget.profileState ||
      createVault != oldWidget.createVault ||
      openVault != oldWidget.openVault ||
      switchVault != oldWidget.switchVault ||
      moveVault != oldWidget.moveVault;
}
