import 'package:flutter/material.dart';

class ObjectBodyObjectReferenceCandidate {
  const ObjectBodyObjectReferenceCandidate({
    required this.objectId,
    required this.title,
    required this.objectTypeName,
    required this.objectTypeIcon,
  });

  final int objectId;
  final String title;
  final String objectTypeName;
  final String objectTypeIcon;
}

Future<int?> showObjectBodyObjectReferencePicker(
  BuildContext context, {
  required List<ObjectBodyObjectReferenceCandidate> candidates,
}) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => _ObjectBodyObjectReferencePickerDialog(
      candidates: candidates,
    ),
  );
}

class _ObjectBodyObjectReferencePickerDialog extends StatefulWidget {
  const _ObjectBodyObjectReferencePickerDialog({required this.candidates});

  final List<ObjectBodyObjectReferenceCandidate> candidates;

  @override
  State<_ObjectBodyObjectReferencePickerDialog> createState() =>
      _ObjectBodyObjectReferencePickerDialogState();
}

class _ObjectBodyObjectReferencePickerDialogState
    extends State<_ObjectBodyObjectReferencePickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.candidates
        : widget.candidates
            .where(
              (candidate) =>
                  candidate.title.toLowerCase().contains(query) ||
                  candidate.objectTypeName.toLowerCase().contains(query),
            )
            .toList(growable: false);

    return AlertDialog(
      title: const Text('Objectを参照'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('body-object-reference-search'),
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Object名またはObjectTypeで検索',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('参照できるObjectがありません'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final candidate = visible[index];
                        return ListTile(
                          key: ValueKey(
                            'body-object-reference-candidate-${candidate.objectId}',
                          ),
                          leading: Text(candidate.objectTypeIcon),
                          title: Text(candidate.title),
                          subtitle: Text(candidate.objectTypeName),
                          onTap: () => Navigator.pop(
                            context,
                            candidate.objectId,
                          ),
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
