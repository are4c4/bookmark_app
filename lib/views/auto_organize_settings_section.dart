import 'package:flutter/material.dart';

import '../data/bookmark_repository.dart';
import '../services/auto_organize_service.dart';
import '../ui/ui_tokens.dart';
import '../widgets/app_empty_state.dart';

class AutoOrganizeSettingsSection extends StatefulWidget {
  const AutoOrganizeSettingsSection({
    super.key,
    required this.repository,
  });

  final BookmarkRepository repository;

  @override
  State<AutoOrganizeSettingsSection> createState() =>
      _AutoOrganizeSettingsSectionState();
}

class _AutoOrganizeSettingsSectionState
    extends State<AutoOrganizeSettingsSection> {
  List<AutoOrganizeRule> _rules = const [];
  bool _loading = true;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rules = await widget.repository.listAutoOrganizeRules();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _loading = false;
    });
  }

  Future<void> _addRule() async {
    final draft = await showDialog<_AutoOrganizeRuleDraft>(
      context: context,
      builder: (context) => const _AutoOrganizeRuleDialog(),
    );
    if (draft == null) return;
    try {
      await widget.repository.createAutoOrganizeRule(
        name: draft.name,
        matchField: draft.matchField,
        keyword: draft.keyword,
        tagName: draft.tagName,
        genre: draft.genre,
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ルールを保存できませんでした: $error')),
      );
    }
  }

  Future<void> _runAll() async {
    setState(() => _running = true);
    try {
      final result = await widget.repository.applyAutoOrganizeToAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.bookmarksChanged}件を整理しました'
            '（ルール一致 ${result.rulesMatched}件）',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('自動整理を実行できませんでした: $error')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _toggle(AutoOrganizeRule rule, bool enabled) async {
    await widget.repository.setAutoOrganizeRuleEnabled(rule.id, enabled);
    await _reload();
  }

  Future<void> _delete(AutoOrganizeRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ルールを削除'),
        content: Text('「${rule.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.deleteAutoOrganizeRule(rule.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '自動整理',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading || _running ? null : _runAll,
              icon: _running
                  ? const SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high_outlined, size: 17),
              label: const Text('既存データに適用'),
            ),
            const SizedBox(width: UiTokens.space8),
            FilledButton.icon(
              onPressed: _addRule,
              icon: const Icon(Icons.add, size: 17),
              label: const Text('ルール追加'),
            ),
          ],
        ),
        const SizedBox(height: UiTokens.space8),
        Text(
          'URL・タイトル・説明にキーワードが含まれるブックマークへ、'
          'タグやジャンルを自動で付与します。新規作成と編集時にも適用されます。',
          style: TextStyle(
            fontSize: UiTokens.textSm,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: UiTokens.space16),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_rules.isEmpty)
          const AppEmptyState(
            icon: Icons.auto_fix_high_outlined,
            title: '自動整理ルールはありません',
            message: 'ルールを追加すると、ブックマークの登録・編集時に自動で整理できます。',
          )
        else
          Card(
            child: Column(
              children: [
                for (var index = 0; index < _rules.length; index++) ...[
                  _RuleTile(
                    rule: _rules[index],
                    onEnabledChanged: (enabled) =>
                        _toggle(_rules[index], enabled),
                    onDelete: () => _delete(_rules[index]),
                  ),
                  if (index < _rules.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onEnabledChanged,
    required this.onDelete,
  });

  final AutoOrganizeRule rule;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final actions = [
      if (rule.tagName.isNotEmpty) 'タグ「${rule.tagName}」',
      if (rule.genre.isNotEmpty) 'ジャンル「${rule.genre}」',
    ].join('・');
    return ListTile(
      leading: Switch(
        value: rule.enabled,
        onChanged: onEnabledChanged,
      ),
      title: Text(rule.name),
      subtitle: Text(
        '${rule.matchField.label}に「${rule.keyword}」を含む → $actions',
      ),
      trailing: IconButton(
        tooltip: '削除',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

class _AutoOrganizeRuleDraft {
  const _AutoOrganizeRuleDraft({
    required this.name,
    required this.matchField,
    required this.keyword,
    required this.tagName,
    required this.genre,
  });

  final String name;
  final AutoOrganizeMatchField matchField;
  final String keyword;
  final String tagName;
  final String genre;
}

class _AutoOrganizeRuleDialog extends StatefulWidget {
  const _AutoOrganizeRuleDialog();

  @override
  State<_AutoOrganizeRuleDialog> createState() =>
      _AutoOrganizeRuleDialogState();
}

class _AutoOrganizeRuleDialogState extends State<_AutoOrganizeRuleDialog> {
  final _nameController = TextEditingController();
  final _keywordController = TextEditingController();
  final _tagController = TextEditingController();
  final _genreController = TextEditingController();
  AutoOrganizeMatchField _field = AutoOrganizeMatchField.all;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _keywordController.dispose();
    _tagController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final keyword = _keywordController.text.trim();
    final tag = _tagController.text.trim();
    final genre = _genreController.text.trim();
    if (name.isEmpty || keyword.isEmpty) {
      setState(() => _error = 'ルール名とキーワードを入力してください。');
      return;
    }
    if (tag.isEmpty && genre.isEmpty) {
      setState(() => _error = '付与するタグまたはジャンルを入力してください。');
      return;
    }
    Navigator.pop(
      context,
      _AutoOrganizeRuleDraft(
        name: name,
        matchField: _field,
        keyword: keyword,
        tagName: tag,
        genre: genre,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('自動整理ルールを追加'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'ルール名'),
              ),
              const SizedBox(height: UiTokens.space12),
              DropdownButtonFormField<AutoOrganizeMatchField>(
                initialValue: _field,
                decoration: const InputDecoration(labelText: '検索対象'),
                items: [
                  for (final field in AutoOrganizeMatchField.values)
                    DropdownMenuItem(
                      value: field,
                      child: Text(field.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _field = value);
                },
              ),
              const SizedBox(height: UiTokens.space12),
              TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: 'キーワード',
                  hintText: '例: youtube.com',
                ),
              ),
              const SizedBox(height: UiTokens.space12),
              TextField(
                controller: _tagController,
                decoration: const InputDecoration(
                  labelText: '付与するタグ（任意）',
                  hintText: '例: YouTube',
                ),
              ),
              const SizedBox(height: UiTokens.space12),
              TextField(
                controller: _genreController,
                decoration: const InputDecoration(
                  labelText: '設定するジャンル（任意）',
                  hintText: '例: 動画',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: UiTokens.space12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: _submit,
            child: const Text('追加'),
          ),
        ],
      );
}
