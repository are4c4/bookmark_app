import 'package:flutter/material.dart';

class ObjectBodyDatabaseViewReferenceCandidate {
  const ObjectBodyDatabaseViewReferenceCandidate({
    required this.databaseId,
    required this.databaseName,
    required this.databaseIcon,
    this.viewId,
    this.viewName,
  });

  final int databaseId;
  final String databaseName;
  final String databaseIcon;
  final int? viewId;
  final String? viewName;

  String get displayName => viewName ?? databaseName;
}

Future<ObjectBodyDatabaseViewReferenceCandidate?>
    showObjectBodyDatabaseViewReferencePicker(
  BuildContext context, {
  required List<ObjectBodyDatabaseViewReferenceCandidate> candidates,
}) {
  return showDialog<ObjectBodyDatabaseViewReferenceCandidate>(
    context: context,
    builder: (_) => _ObjectBodyDatabaseViewReferencePickerDialog(
      candidates: candidates,
    ),
  );
}

class _ObjectBodyDatabaseViewReferencePickerDialog extends StatefulWidget {
  const _ObjectBodyDatabaseViewReferencePickerDialog({
    required this.candidates,
  });

  final List<ObjectBodyDatabaseViewReferenceCandidate> candidates;

  @override
  State<_ObjectBodyDatabaseViewReferencePickerDialog> createState() =>
      _ObjectBodyDatabaseViewReferencePickerDialogState();
}

class _ObjectBodyDatabaseViewReferencePickerDialogState
    extends State<_ObjectBodyDatabaseViewReferencePickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.candidates
        : widget.candidates
            .where(
              (candidate) =>
                  candidate.databaseName.toLowerCase().contains(query) ||
                  (candidate.viewName?.toLowerCase().contains(query) ?? false),
            )
            .toList(growable: false);

    return AlertDialog(
      title: const Text('Database / Viewを埋め込む'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('body-database-view-reference-search'),
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Database名またはView名で検索',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('埋め込めるDatabase / Viewがありません'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final candidate = visible[index];
                        final suffix = candidate.viewId == null
                            ? 'database'
                            : 'view-${candidate.viewId}';
                        return ListTile(
                          key: ValueKey(
                            'body-database-view-reference-${candidate.databaseId}-$suffix',
                          ),
                          leading: Text(candidate.databaseIcon),
                          title: Text(candidate.displayName),
                          subtitle: Text(
                            candidate.viewId == null
                                ? 'Database'
                                : candidate.databaseName,
                          ),
                          onTap: () => Navigator.pop(context, candidate),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ],
    );
  }
}
