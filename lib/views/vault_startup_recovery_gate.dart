import 'dart:async';

import 'package:flutter/material.dart';

import '../services/vault_registry_inspection_service.dart';
import '../services/vault_startup_recovery_controller.dart';
import '../ui/ui_tokens.dart';
import 'vault_recovery_page.dart';

/// Resolves Vault-specific bootstrap failures without exposing raw filesystem
/// errors or constructing a replacement database.
///
/// The normal app bootstrap remains the owner of database creation/opening. This
/// gate only inspects the registry and delegates relink/unregister operations to
/// the Storage recovery controller, then asks the host to retry normal startup.
class VaultStartupRecoveryGate extends StatefulWidget {
  const VaultStartupRecoveryGate({
    super.key,
    required this.onRetryBootstrap,
    this.controller,
  });

  final Future<void> Function() onRetryBootstrap;
  final VaultStartupRecoveryController? controller;

  @override
  State<VaultStartupRecoveryGate> createState() =>
      _VaultStartupRecoveryGateState();
}

class _VaultStartupRecoveryGateState extends State<VaultStartupRecoveryGate> {
  late final VaultStartupRecoveryController _controller =
      widget.controller ?? VaultStartupRecoveryController.fromServices();

  List<VaultRegistryLocation>? _locations;
  bool _inspectionFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_inspect());
  }

  Future<void> _inspect() async {
    try {
      final locations = await _controller.inspect();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _inspectionFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locations = null;
        _inspectionFailed = true;
      });
    }
  }

  Future<void> _afterRegistryChange() async {
    final locations = await _controller.inspect();
    final unavailable = locations.where((location) => !location.isAvailable);
    if (unavailable.isEmpty) {
      await widget.onRetryBootstrap();
      return;
    }
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _inspectionFailed = false;
    });
  }

  Future<void> _relink(VaultRegistryLocation location) async {
    final changed = await _controller.relink(location);
    if (!changed) return;
    await _afterRegistryChange();
  }

  Future<void> _unregisterInactive(VaultRegistryLocation location) async {
    await _controller.unregisterInactive(location);
    await _afterRegistryChange();
  }

  Widget _genericFailure({required bool recoveryInspectionFailed}) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(UiTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                recoveryInspectionFailed
                    ? 'Vaultの復旧情報を読み込めませんでした。'
                    : 'Vaultの保存場所に問題は見つかりませんでした。起動をもう一度お試しください。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: UiTokens.space16),
              FilledButton.icon(
                onPressed: () => unawaited(widget.onRetryBootstrap()),
                icon: const Icon(Icons.refresh),
                label: const Text('もう一度起動する'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_inspectionFailed) {
      return _genericFailure(recoveryInspectionFailed: true);
    }
    final locations = _locations;
    if (locations == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (locations.every((location) => location.isAvailable)) {
      return _genericFailure(recoveryInspectionFailed: false);
    }
    return VaultRecoveryPage(
      locations: locations,
      onRelink: _relink,
      onUnregisterInactive: _unregisterInactive,
      onRetry: () => unawaited(widget.onRetryBootstrap()),
    );
  }
}
