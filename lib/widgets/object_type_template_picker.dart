import 'package:flutter/material.dart';

import '../data/object_type_template_store.dart';

sealed class ObjectTypeCreationChoice {
  const ObjectTypeCreationChoice();
}

class EmptyObjectTypeChoice extends ObjectTypeCreationChoice {
  const EmptyObjectTypeChoice();
}

class TemplateObjectTypeChoice extends ObjectTypeCreationChoice {
  const TemplateObjectTypeChoice(this.template);

  final ObjectTypeTemplate template;
}

Future<ObjectTypeCreationChoice?> showObjectTypeTemplatePicker(
  BuildContext context,
) {
  return showDialog<ObjectTypeCreationChoice>(
    context: context,
    builder: (dialogContext) => const ObjectTypeTemplatePickerDialog(),
  );
}

class ObjectTypeTemplatePickerDialog extends StatefulWidget {
  const ObjectTypeTemplatePickerDialog({super.key});

  @override
  State<ObjectTypeTemplatePickerDialog> createState() =>
      _ObjectTypeTemplatePickerDialogState();
}

class _ObjectTypeTemplatePickerDialogState
    extends State<ObjectTypeTemplatePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ObjectTypeTemplate> get _visibleTemplates {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return ObjectTypeTemplateStore.templates;
    return ObjectTypeTemplateStore.templates.where((template) {
      final propertySearchText = template.properties.map((property) {
        return [
          property.name,
          property.type,
          property.relationTargetSystemKey ?? '',
        ].join(' ');
      }).join(' ');
      final viewSearchText = template.views
          .map((view) => '${view.name} ${view.layoutType}')
          .join(' ');
      final searchText = [
        template.key,
        template.name,
        template.description,
        propertySearchText,
        viewSearchText,
      ].join(' ').toLowerCase();
      return searchText.contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleTemplates = _visibleTemplates;
    return AlertDialog(
      title: const Text('データベースを追加'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          key: const ValueKey('object-type-template-picker-scroll'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChoiceTile(
                icon: '＋',
                title: '空のデータベース',
                subtitle: 'プロパティを自分で追加して一から作成します',
                onTap: () => Navigator.pop(
                  context,
                  const EmptyObjectTypeChoice(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              TextField(
                key: const ValueKey('object-type-template-search'),
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'テンプレートを検索',
                  hintText: '名前・用途・プロパティ',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          key: const ValueKey('object-type-template-search-clear'),
                          tooltip: '検索をクリア',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  _query.trim().isEmpty
                      ? 'テンプレート'
                      : 'テンプレート · ${visibleTemplates.length}件',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (visibleTemplates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                  child: Text(
                    '一致するテンプレートがありません。空のデータベースから作成することもできます。',
                    key: ValueKey('object-type-template-empty-result'),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...visibleTemplates.map(
                  (template) => _ChoiceTile(
                    key: ValueKey('object-type-template-${template.key}'),
                    icon: template.icon,
                    title: template.name,
                    subtitle: template.description,
                    onTap: () => Navigator.pop(
                      context,
                      TemplateObjectTypeChoice(template),
                    ),
                  ),
                ),
            ],
          ),
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

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: SizedBox(
        width: 32,
        child: Center(
          child: Text(icon, style: const TextStyle(fontSize: 20)),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}
