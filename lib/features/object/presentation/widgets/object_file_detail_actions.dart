import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../../services/canonical_file_action_service.dart';
import '../../../../services/canonical_file_export_service.dart';

typedef ObjectFileExportDestinationPicker = Future<String?> Function();

/// Reusable native actions for one canonical File Object.
///
/// Presentation hosts receive only canonical File services and Object identity;
/// they never resolve raw paths themselves. Open/reveal/export therefore stay
/// behind the same system-File identity and missing-file safety gates as other
/// native File capability consumers.
class ObjectFileDetailActions extends StatefulWidget {
  const ObjectFileDetailActions({
    super.key,
    required this.actions,
    required this.exporter,
    required this.fileObjectTypeId,
    required this.fileObjectId,
    this.exportDestinationPicker,
    this.onError,
  });

  final CanonicalFileActionService actions;
  final CanonicalFileExportService exporter;
  final int fileObjectTypeId;
  final int fileObjectId;
  final ObjectFileExportDestinationPicker? exportDestinationPicker;
  final ValueChanged<Object>? onError;

  @override
  State<ObjectFileDetailActions> createState() =>
      _ObjectFileDetailActionsState();
}

class _ObjectFileDetailActionsState extends State<ObjectFileDetailActions> {
  static const _failureMessage = 'ファイル操作に失敗しました。';

  bool _running = false;
  String? _errorMessage;

  Future<String?> _pickExportDestination() async {
    final picker = widget.exportDestinationPicker;
    if (picker != null) return picker();
    final location = await getSaveLocation();
    return location?.path;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_running) return;
    setState(() {
      _running = true;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (error) {
      widget.onError?.call(error);
      if (mounted) {
        setState(() => _errorMessage = _failureMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  Future<void> _export() async {
    final destination = (await _pickExportDestination())?.trim();
    if (destination == null || destination.isEmpty) return;
    await widget.exporter.exportTo(
      fileObjectTypeId: widget.fileObjectTypeId,
      fileObjectId: widget.fileObjectId,
      destinationPath: destination,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('object-file-detail-actions-${widget.fileObjectId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: ValueKey('object-file-open-${widget.fileObjectId}'),
              onPressed: _running
                  ? null
                  : () => _run(
                        () => widget.actions.open(
                          fileObjectTypeId: widget.fileObjectTypeId,
                          fileObjectId: widget.fileObjectId,
                        ),
                      ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('開く'),
            ),
            OutlinedButton.icon(
              key: ValueKey('object-file-reveal-${widget.fileObjectId}'),
              onPressed: _running
                  ? null
                  : () => _run(
                        () => widget.actions.reveal(
                          fileObjectTypeId: widget.fileObjectTypeId,
                          fileObjectId: widget.fileObjectId,
                        ),
                      ),
              icon: const Icon(Icons.folder_open),
              label: const Text('場所を表示'),
            ),
            OutlinedButton.icon(
              key: ValueKey('object-file-export-${widget.fileObjectId}'),
              onPressed: _running ? null : () => _run(_export),
              icon: const Icon(Icons.download),
              label: const Text('書き出す'),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            key: const ValueKey('object-file-detail-actions-error'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
      ],
    );
  }
}
