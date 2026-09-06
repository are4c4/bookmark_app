import 'package:flutter/material.dart';

import '../services/profile_manager.dart';
import '../ui/ui_tokens.dart';

Future<DatabaseProfile?> showVaultSwitchDialog(
  BuildContext context, {
  required ProfileState state,
}) =>
    showDialog<DatabaseProfile>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vaultを切り替える'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: state.profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: UiTokens.space4),
            itemBuilder: (context, index) {
              final profile = state.profiles[index];
              final selected = profile.id == state.activeProfileId;
              return ListTile(
                selected: selected,
                leading: Icon(
                  selected ? Icons.check_circle : Icons.folder_outlined,
                ),
                title: Text(profile.name),
                subtitle: Text(
                  profile.directoryPath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: selected
                    ? null
                    : () => Navigator.pop(dialogContext, profile),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );
