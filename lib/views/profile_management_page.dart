import 'dart:io';

import 'package:flutter/material.dart';

import '../services/profile_manager.dart';

class ProfileManagementPage extends StatelessWidget {
  const ProfileManagementPage({
    super.key,
    required this.state,
    required this.onSwitch,
    required this.onCreate,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  final ProfileState state;
  final Future<void> Function(DatabaseProfile profile) onSwitch;
  final Future<void> Function(String name) onCreate;
  final Future<void> Function(DatabaseProfile profile, String name) onRename;
  final Future<void> Function(DatabaseProfile profile) onDuplicate;
  final Future<void> Function(DatabaseProfile profile) onDelete;

  Future<void> _openFolder(DatabaseProfile profile) async {
    if (Platform.isMacOS) {
      await Process.run('/usr/bin/open', [profile.directoryPath]);
    }
  }

  Future<String?> _askName(BuildContext context, String title, {String initial = ''}) async {
    var value = initial;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          onChanged: (text) => value = text,
          onFieldSubmitted: (_) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(context, value.trim()), child: const Text('保存')),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final name = await _askName(context, 'Profileを追加');
    if (name?.isNotEmpty == true) await onCreate(name!);
  }

  Future<void> _rename(BuildContext context, DatabaseProfile profile) async {
    final name = await _askName(context, 'Profile名を変更', initial: profile.name);
    if (name?.isNotEmpty == true) await onRename(profile, name!);
  }

  Future<void> _delete(BuildContext context, DatabaseProfile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「${profile.name}」を削除しますか？'),
        content: const Text('Profileフォルダ内のデータベースと写真も削除されます。この操作は元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok == true) await onDelete(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile管理'),
        actions: [
          TextButton.icon(onPressed: () => _create(context), icon: const Icon(Icons.add), label: const Text('Profileを追加')),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: state.profiles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final profile = state.profiles[index];
          final active = profile.id == state.activeProfileId;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: active ? const Color(0xFFEFEFED) : const Color(0xFFF7F7F5),
                    child: Icon(active ? Icons.account_circle : Icons.person_outline),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(child: Text(profile.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                          if (active) ...[
                            const SizedBox(width: 8),
                            const Chip(label: Text('使用中')),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Text(profile.directoryPath, style: const TextStyle(fontSize: 12, color: Color(0xFF787774))),
                      ],
                    ),
                  ),
                  if (!active)
                    TextButton(onPressed: () => onSwitch(profile), child: const Text('切り替え')),
                  IconButton(tooltip: 'Finderで開く', onPressed: () => _openFolder(profile), icon: const Icon(Icons.folder_open_outlined)),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') _rename(context, profile);
                      if (value == 'duplicate') onDuplicate(profile);
                      if (value == 'delete') _delete(context, profile);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('名前を変更')),
                      const PopupMenuItem(value: 'duplicate', child: Text('複製')),
                      if (!profile.isDefault && !active)
                        const PopupMenuItem(value: 'delete', child: Text('削除')),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
