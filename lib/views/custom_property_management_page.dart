import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../data/custom_property_store.dart';

class CustomPropertyManagementPage extends StatefulWidget {
  const CustomPropertyManagementPage({super.key, required this.repository});

  final BookmarkRepository repository;

  @override
  State<CustomPropertyManagementPage> createState() =>
      _CustomPropertyManagementPageState();
}

class _CustomPropertyManagementPageState
    extends State<CustomPropertyManagementPage> {
  int _refreshToken = 0;

  Future<List<BookmarkPropertyDefinition>> _load() =>
      widget.repository.getCustomPropertyDefinitions();

  static String _typeLabel(BookmarkPropertyType type) => switch (type) {
        BookmarkPropertyType.text => 'テキスト',
        BookmarkPropertyType.number => '数値',
        BookmarkPropertyType.date => '日付',
        BookmarkPropertyType.select => '選択肢',
        BookmarkPropertyType.checkbox => 'チェックボックス',
      };

  static IconData _typeIcon(BookmarkPropertyType type) => switch (type) {
        BookmarkPropertyType.text => Icons.text_fields,
        BookmarkPropertyType.number => Icons.numbers,
        BookmarkPropertyType.date => Icons.calendar_today_outlined,
        BookmarkPropertyType.select => Icons.list_alt_outlined,
        BookmarkPropertyType.checkbox => Icons.check_box_outlined,
      };

  List<String> _parseOptions(String value) => value
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _edit({BookmarkPropertyDefinition? definition}) async {
    final name = TextEditingController(text: definition?.name ?? '');
    final options = TextEditingController(
      text: definition?.options.join(', ') ?? '',
    );
    var type = definition?.type ?? BookmarkPropertyType.text;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(definition == null ? 'カスタム項目を追加' : 'カスタム項目を編集'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '項目名',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BookmarkPropertyType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: '種類',
                    border: OutlineInputBorder(),
                  ),
                  items: BookmarkPropertyType.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Row(
                            children: [
                              Icon(_typeIcon(value), size: 18),
                              const SizedBox(width: 8),
                              Text(_typeLabel(value)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setLocalState(() => type = value);
                  },
                ),
                if (type == BookmarkPropertyType.select) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: options,
                    decoration: const InputDecoration(
                      labelText: '選択肢（カンマ区切り）',
                      hintText: '未読, 視聴中, 完了',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                if (definition == null) {
                  await widget.repository.createCustomProperty(
                    name: name.text.trim(),
                    type: type,
                    options: _parseOptions(options.text),
                  );
                } else {
                  await widget.repository.updateCustomProperty(
                    definition,
                    name: name.text.trim(),
                    type: type,
                    options: _parseOptions(options.text),
                  );
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    options.dispose();
    if (saved == true && mounted) setState(() => _refreshToken++);
  }

  Future<void> _delete(BookmarkPropertyDefinition definition) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('カスタム項目を削除しますか？'),
        content: Text(
          '「${definition.name}」と、すべてのブックマークに保存されているこの項目の値を削除します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteCustomProperty(definition);
      if (mounted) setState(() => _refreshToken++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロパティ管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('項目を追加'),
      ),
      body: FutureBuilder<List<BookmarkPropertyDefinition>>(
        key: ValueKey(_refreshToken),
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final definitions = snapshot.data ?? const <BookmarkPropertyDefinition>[];
          if (definitions.isEmpty) {
            return const Center(
              child: Text('カスタム項目がありません。右下から追加できます。'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: definitions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final definition = definitions[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(_typeIcon(definition.type)),
                ),
                title: Text(definition.name),
                subtitle: Text(
                  definition.type == BookmarkPropertyType.select &&
                          definition.options.isNotEmpty
                      ? '${_typeLabel(definition.type)} • ${definition.options.join(' / ')}'
                      : _typeLabel(definition.type),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _edit(definition: definition);
                    if (value == 'delete') _delete(definition);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('編集')),
                    PopupMenuItem(value: 'delete', child: Text('削除')),
                  ],
                ),
                onTap: () => _edit(definition: definition),
              );
            },
          );
        },
      ),
    );
  }
}
