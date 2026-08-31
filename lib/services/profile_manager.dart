import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DatabaseProfile {
  const DatabaseProfile({
    required this.id,
    required this.name,
    required this.databaseName,
  });

  final String id;
  final String name;
  final String databaseName;

  bool get isDefault => id == 'default';

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'databaseName': databaseName,
      };

  factory DatabaseProfile.fromJson(Map<String, Object?> json) => DatabaseProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        databaseName: json['databaseName'] as String,
      );
}

class ProfileState {
  const ProfileState({required this.profiles, required this.activeProfileId});

  final List<DatabaseProfile> profiles;
  final String activeProfileId;

  DatabaseProfile get activeProfile => profiles.firstWhere(
        (profile) => profile.id == activeProfileId,
        orElse: () => profiles.first,
      );
}

class ProfileManager {
  ProfileManager._(this._file, this._state);

  final File _file;
  ProfileState _state;

  ProfileState get state => _state;

  static Future<ProfileManager> load() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/bookmark_profiles.json');

    if (!await file.exists()) {
      final initial = ProfileState(
        profiles: const [
          DatabaseProfile(
            id: 'default',
            name: 'Default',
            databaseName: 'bookmark_app',
          ),
        ],
        activeProfileId: 'default',
      );
      final manager = ProfileManager._(file, initial);
      await manager._save();
      return manager;
    }

    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final profiles = (raw['profiles'] as List<dynamic>? ?? const [])
          .map((item) => DatabaseProfile.fromJson(Map<String, Object?>.from(item as Map)))
          .toList();
      if (profiles.isEmpty) {
        profiles.add(const DatabaseProfile(
          id: 'default',
          name: 'Default',
          databaseName: 'bookmark_app',
        ));
      }
      final requestedActive = raw['activeProfileId'] as String? ?? 'default';
      final active = profiles.any((profile) => profile.id == requestedActive)
          ? requestedActive
          : profiles.first.id;
      return ProfileManager._(
        file,
        ProfileState(profiles: profiles, activeProfileId: active),
      );
    } catch (_) {
      final initial = ProfileState(
        profiles: const [
          DatabaseProfile(
            id: 'default',
            name: 'Default',
            databaseName: 'bookmark_app',
          ),
        ],
        activeProfileId: 'default',
      );
      final manager = ProfileManager._(file, initial);
      await manager._save();
      return manager;
    }
  }

  Future<DatabaseProfile> createProfile(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Profile name is empty');

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final profile = DatabaseProfile(
      id: id,
      name: trimmed,
      databaseName: 'bookmark_app_profile_$id',
    );
    _state = ProfileState(
      profiles: [..._state.profiles, profile],
      activeProfileId: _state.activeProfileId,
    );
    await _save();
    return profile;
  }

  Future<void> setActiveProfile(DatabaseProfile profile) async {
    if (!_state.profiles.any((candidate) => candidate.id == profile.id)) return;
    _state = ProfileState(
      profiles: _state.profiles,
      activeProfileId: profile.id,
    );
    await _save();
  }

  Future<void> renameProfile(DatabaseProfile profile, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _state = ProfileState(
      profiles: _state.profiles
          .map((candidate) => candidate.id == profile.id
              ? DatabaseProfile(
                  id: candidate.id,
                  name: trimmed,
                  databaseName: candidate.databaseName,
                )
              : candidate)
          .toList(),
      activeProfileId: _state.activeProfileId,
    );
    await _save();
  }

  Future<void> _save() async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'activeProfileId': _state.activeProfileId,
        'profiles': _state.profiles.map((profile) => profile.toJson()).toList(),
      }),
      flush: true,
    );
  }
}
