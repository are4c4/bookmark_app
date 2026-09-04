import 'package:flutter/material.dart';

class ObjectBodyObjectReferenceCandidate {
  const ObjectBodyObjectReferenceCandidate({
    required this.objectId,
    required this.title,
    required this.objectTypeName,
    required this.objectTypeIcon,
    this.aliases = const <String>[],
  });

  final int objectId;
  final String title;
  final String objectTypeName;
  final String objectTypeIcon;
  final List<String> aliases;

  String? matchingAlias(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return null;
    for (final alias in aliases) {
      if (alias.toLowerCase().contains(normalizedQuery)) return alias;
    }
    return null;
  }

  bool matches(String normalizedQuery) =>
      normalizedQuery.isEmpty ||
      title.toLowerCase().contains(normalizedQuery) ||
      objectTypeName.toLowerCase().contains(normalizedQuery) ||
      matchingAlias(normalizedQuery) != null;
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
    final visible = widget.candidates
        .where((candidate) => candidate.matches(query))
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
                hintText: 'Object名・別名・ObjectTypeで検索',
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
                        final matchedAlias = candidate.matchingAlias(query);
                        return ListTile(
                          key: ValueKey(
                            'body-object-reference-candidate-${candidate.objectId}',
                          ),
                          leading: Text(candidate.objectTypeIcon),
                          title: Text(candidate.title),
                          subtitle: Text(
                            matchedAlias == null
                                ? candidate.objectTypeName
                                : '${candidate.objectTypeName} · 別名: $matchedAlias',
                          ),
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
