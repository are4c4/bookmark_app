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

class ObjectTypeTemplatePickerDialog extends StatelessWidget {
  const ObjectTypeTemplatePickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('データベースを追加'),
      content: SizedBox(
        width: 520,
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
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'テンプレート',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...ObjectTypeTemplateStore.templates.map(
              (template) => _ChoiceTile(
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
