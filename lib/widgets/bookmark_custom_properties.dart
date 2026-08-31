import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../data/custom_property_store.dart';

class BookmarkCustomProperties extends StatefulWidget {
  const BookmarkCustomProperties({
    super.key,
    required this.repository,
    required this.bookmarkId,
  });

  final BookmarkRepository repository;
  final int bookmarkId;

  @override
  State<BookmarkCustomProperties> createState() => _BookmarkCustomPropertiesState();
}

class _BookmarkCustomPropertiesState extends State<BookmarkCustomProperties> {
  int _refreshToken = 0;

  @override
  void didUpdateWidget(covariant BookmarkCustomProperties oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookmarkId != widget.bookmarkId) {
      _refreshToken++;
    }
  }

  Future<List<BookmarkPropertyValue>> _load() =>
      widget.repository.getCustomPropertyValues(widget.bookmarkId);

  String _displayValue(BookmarkPropertyValue item) {
    final value = item.value;
    if (item.definition.type == BookmarkPropertyType.checkbox) {
      return value == 'true' ? '✓' : '—';
    }
    if (value == null || value.trim().isEmpty) return '未設定';
    return value;
  }

  Future<void> _editValue(BookmarkPropertyValue item) async {
    final definition = item.definition;
    final controller = TextEditingController(text: item.value ?? '');
    var checkboxValue = item.value == 'true';
    String? selectValue = definition.options.contains(item.value) ? item.value : null;
    DateTime? selectedDate = DateTime.tryParse(item.value ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          Widget editor;
          switch (definition.type) {
            case BookmarkPropertyType.text:
              editor = TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              );
            case BookmarkPropertyType.number:
              editor = TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              );
            case BookmarkPropertyType.date:
              editor = Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedDate == null
                          ? '日付が設定されていません'
                          : '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2200),
                        initialDate: selectedDate ?? DateTime.now(),
                      );
                      if (picked != null) setLocalState(() => selectedDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('日付を選択'),
                  ),
                ],
              );
            case BookmarkPropertyType.select:
              editor = DropdownButtonFormField<String>(
                initialValue: selectValue,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '選択肢',
                ),
                items: definition.options
                    .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                    .toList(),
                onChanged: (value) => setLocalState(() => selectValue = value),
              );
            case BookmarkPropertyType.checkbox:
              editor = SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('チェック'),
                value: checkboxValue,
                onChanged: (value) => setLocalState(() => checkboxValue = value),
              );
          }

          return AlertDialog(
            title: Text(definition.name),
            content: SizedBox(width: 430, child: editor),
            actions: [
              TextButton(
                onPressed: () async {
                  await widget.repository.setCustomPropertyValue(
                    widget.bookmarkId,
                    definition,
                    null,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                },
                child: const Text('値をクリア'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  String? value;
                  switch (definition.type) {
                    case BookmarkPropertyType.text:
                    case BookmarkPropertyType.number:
                      value = controller.text.trim().isEmpty ? null : controller.text.trim();
                    case BookmarkPropertyType.date:
                      value = selectedDate == null
                          ? null
                          : '${selectedDate!.year.toString().padLeft(4, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
                    case BookmarkPropertyType.select:
                      value = selectValue;
                    case BookmarkPropertyType.checkbox:
                      value = checkboxValue ? 'true' : 'false';
                  }
                  await widget.repository.setCustomPropertyValue(
                    widget.bookmarkId,
                    definition,
                    value,
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
    if (saved == true && mounted) setState(() => _refreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BookmarkPropertyValue>>(
      key: ValueKey('${widget.bookmarkId}-$_refreshToken'),
      future: _load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 36,
            child: Center(child: LinearProgressIndicator()),
          );
        }
        final values = snapshot.data ?? const <BookmarkPropertyValue>[];
        if (values.isEmpty) {
          return Text(
            'カスタム項目はありません。「プロパティ管理」から追加できます。',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Column(
          children: values
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          item.definition.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _displayValue(item),
                          style: TextStyle(
                            color: item.value == null
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '編集',
                        onPressed: () => _editValue(item),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
