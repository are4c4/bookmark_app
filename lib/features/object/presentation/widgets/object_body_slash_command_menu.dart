import 'package:flutter/material.dart';

import '../../../../domain/object_body.dart';
import '../../../../domain/object_body_block_actions.dart';
import '../../../../domain/object_body_block_contracts.dart';

enum ObjectBodySlashCommandKind { convert, insert }

class ObjectBodySlashCommand {
  const ObjectBodySlashCommand({
    required this.id,
    required this.label,
    required this.keywords,
    required this.kind,
    this.targetType,
    this.headingLevel,
    this.insertKind,
  });

  final String id;
  final String label;
  final List<String> keywords;
  final ObjectBodySlashCommandKind kind;
  final String? targetType;
  final int? headingLevel;
  final ObjectBodyInsertKind? insertKind;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (label.toLowerCase().contains(normalized)) return true;
    return keywords.any((item) => item.toLowerCase().contains(normalized));
  }

  static const commands = <ObjectBodySlashCommand>[
    ObjectBodySlashCommand(
      id: 'paragraph',
      label: '本文',
      keywords: ['paragraph', 'text', '本文'],
      kind: ObjectBodySlashCommandKind.convert,
      targetType: ObjectBodyBlockType.paragraph,
    ),
    ObjectBodySlashCommand(
      id: 'heading-1',
      label: '見出し 1',
      keywords: ['heading1', 'h1', '見出し1'],
      kind: ObjectBodySlashCommandKind.convert,
      targetType: ObjectBodyBlockType.heading,
      headingLevel: 1,
    ),
    ObjectBodySlashCommand(
      id: 'heading-2',
      label: '見出し 2',
      keywords: ['heading2', 'h2', '見出し2'],
      kind: ObjectBodySlashCommandKind.convert,
      targetType: ObjectBodyBlockType.heading,
      headingLevel: 2,
    ),
    ObjectBodySlashCommand(
      id: 'heading-3',
      label: '見出し 3',
      keywords: ['heading3', 'h3', '見出し3'],
      kind: ObjectBodySlashCommandKind.convert,
      targetType: ObjectBodyBlockType.heading,
      headingLevel: 3,
    ),
    ObjectBodySlashCommand(
      id: 'bulleted-list',
      label: '箇条書き',
      keywords: ['bullet', 'bulleted', 'list', '箇条書き'],
      kind: ObjectBodySlashCommandKind.convert,
      targetType: ObjectBodyBlockType.bulletedListItem,
    ),
    ObjectBodySlashCommand(
      id: 'numbered-list',
      label: '番号付きリスト',
      keywords: ['number', 'numbered', 'list', '番号'],
      kind: ObjectBodySlashCommandKind.convert,
      targetType: ObjectBodyBlockType.numberedListItem,
    ),
    ObjectBodySlashCommand(
      id: 'checklist',
      label: 'チェックリスト',
      keywords: ['check', 'todo', 'task', 'チェック'],
      kind: ObjectBodySlashCommandKind.convert,
      targetType: ObjectBodyBlockType.checklist,
    ),
    ObjectBodySlashCommand(
      id: 'quote',
      label: '引用',
      keywords: ['quote', '引用'],
      kind: ObjectBodySlashCommandKind.convert,
      targetType: ObjectBodyBlockType.quote,
    ),
    ObjectBodySlashCommand(
      id: 'callout',
      label: 'コールアウト',
      keywords: ['callout', 'note', 'コールアウト'],
      kind: ObjectBodySlashCommandKind.convert,
      targetType: ObjectBodyBlockType.callout,
    ),
    ObjectBodySlashCommand(
      id: 'code',
      label: 'コード',
      keywords: ['code', 'コード'],
      kind: ObjectBodySlashCommandKind.convert,
      targetType: ObjectBodyBlockType.code,
    ),
    ObjectBodySlashCommand(
      id: 'divider',
      label: '区切り線',
      keywords: ['divider', 'rule', 'separator', '区切り'],
      kind: ObjectBodySlashCommandKind.insert,
      insertKind: ObjectBodyInsertKind.divider,
    ),
  ];
}

class ObjectBodySlashCommandInvocation {
  const ObjectBodySlashCommandInvocation({
    required this.objectId,
    required this.blockId,
    required this.sourceText,
    required this.query,
    required this.commandStart,
    required this.commandEnd,
  });

  final int objectId;
  final String blockId;
  final String sourceText;
  final String query;
  final int commandStart;
  final int commandEnd;

  String get replacementText =>
      sourceText.replaceRange(commandStart, commandEnd, '');

  static const _supportedTypes = <String>{
    ObjectBodyBlockType.paragraph,
    ObjectBodyBlockType.heading,
    ObjectBodyBlockType.bulletedListItem,
    ObjectBodyBlockType.numberedListItem,
    ObjectBodyBlockType.checklist,
    ObjectBodyBlockType.quote,
    ObjectBodyBlockType.callout,
    ObjectBodyBlockType.code,
  };

  static final RegExp _trigger = RegExp(r'(^|\s)/([^\s/]*)$');

  static ObjectBodySlashCommandInvocation? tryParse({
    required int objectId,
    required ObjectBodyBlock block,
    required String text,
  }) {
    if (!_supportedTypes.contains(block.type)) return null;
    final match = _trigger.firstMatch(text);
    if (match == null) return null;
    final prefix = match.group(1) ?? '';
    final query = match.group(2) ?? '';
    final commandStart = match.start + prefix.length;
    return ObjectBodySlashCommandInvocation(
      objectId: objectId,
      blockId: block.id,
      sourceText: text,
      query: query,
      commandStart: commandStart,
      commandEnd: text.length,
    );
  }
}

class ObjectBodySlashCommandMenu extends StatelessWidget {
  const ObjectBodySlashCommandMenu({
    super.key,
    required this.query,
    required this.onSelected,
    required this.onDismissed,
  });

  final String query;
  final ValueChanged<ObjectBodySlashCommand> onSelected;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final matches = ObjectBodySlashCommand.commands
        .where((command) => command.matches(query))
        .toList(growable: false);
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        key: const ValueKey('body-slash-command-menu'),
        elevation: 6,
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
          child: matches.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('一致するコマンドがありません'),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const ValueKey('body-slash-command-dismiss'),
                        tooltip: '閉じる',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDismissed,
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final command = matches[index];
                    return ListTile(
                      key: ValueKey('body-slash-command-${command.id}'),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(command.label),
                      onTap: () => onSelected(command),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
