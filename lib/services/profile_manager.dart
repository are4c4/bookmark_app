import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DatabaseProfile {
  const DatabaseProfile({
    required this.id,
    required this.name,
    required this.databaseName,
    required this.directoryPath,
  });

  final String id;
  final String name;
  final String databaseName;
  final String directoryPath;

  bool get isDefault => id == 'default';
  String get databasePath => '$directoryPath/database.sqlite';
  String get photoDirectoryPath => '$directoryPath/photos';
  String get profileMetadataPath => '$directoryPath/profile.json';

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'databaseName': databaseName,
        'directoryPath': directoryPath,
      };

  factory DatabaseProfile.fromJson(Map<String, Object?> json) => DatabaseProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        databaseName: json['databaseName'] as String,
        directoryPath: (json['directoryPath'] as String?) ?? '',
      );

  DatabaseProfile copyWith({String? name, String? directoryPath}) => DatabaseProfile(
        id: id,
        name: name ?? this.name,
        databaseName: databaseName,
        directoryPath: directoryPath ?? this.directoryPath,
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
  ProfileManager._(this._file, this._profilesRoot, this._state);

  final File _file;
  final Directory _profilesRoot;
  ProfileState _state;

  ProfileState get state => _state;

  static Future<ProfileManager> load() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/BookmarkApp/Profiles');
    await root.create(recursive: true);
    final file = File('${support.path}/bookmark_profiles.json');

    ProfileState state;
    if (!await file.exists()) {
      state = ProfileState(
        profiles: [
          DatabaseProfile(
            id: 'default',
            name: 'Default',
            databaseName: 'bookmark_app',
            directoryPath: '${root.path}/default',
          ),
        ],
        activeProfileId: 'default',
      );
    } else {
      try {
        final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        var profiles = (raw['profiles'] as List<dynamic>? ?? const [])
            .map((item) => DatabaseProfile.fromJson(Map<String, Object?>.from(item as Map)))
            .toList();
        if (profiles.isEmpty) {
          profiles = [
            DatabaseProfile(
              id: 'default',
              name: 'Default',
              databaseName: 'bookmark_app',
              directoryPath: '${root.path}/default',
            ),
          ];
        }
        profiles = profiles
            .map((profile) => profile.directoryPath.isEmpty
                ? profile.copyWith(directoryPath: '${root.path}/${profile.id}')
                : profile)
            .toList();
        final requestedActive = raw['activeProfileId'] as String? ?? 'default';
        final active = profiles.any((profile) => profile.id == requestedActive)
            ? requestedActive
            : profiles.first.id;
        state = ProfileState(profiles: profiles, activeProfileId: active);
      } catch (_) {
        state = ProfileState(
          profiles: [
            DatabaseProfile(
              id: 'default',
              name: 'Default',
              databaseName: 'bookmark_app',
              directoryPath: '${root.path}/default',
            ),
          ],
          activeProfileId: 'default',
        );
      }
    }

    final manager = ProfileManager._(file, root, state);
    await manager._prepareProfileFolders();
    await manager._save();
    return manager;
  }

  Future<void> _prepareProfileFolders() async {
    final documents = await getApplicationDocumentsDirectory();
    for (final profile in _state.profiles) {
      final directory = Directory(profile.directoryPath);
      final photos = Directory(profile.photoDirectoryPath);
      await directory.create(recursive: true);
      await photos.create(recursive: true);

      final targetDb = File(profile.databasePath);
      if (!await targetDb.exists()) {
        final legacyDb = File('${documents.path}/${profile.databaseName}.sqlite');
        if (await legacyDb.exists()) {
          await legacyDb.copy(targetDb.path);
          for (final suffix in const ['-wal', '-shm']) {
            final sidecar = File('${legacyDb.path}$suffix');
            if (await sidecar.exists()) {
              await sidecar.copy('${targetDb.path}$suffix');
            }
          }
        }
      }
      await _writeProfileMetadata(profile);
    }
  }

  Future<DatabaseProfile> createProfile(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Profile name is empty');

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final directory = Directory('${_profilesRoot.path}/$id');
    await Directory('${directory.path}/photos').create(recursive: true);
    final profile = DatabaseProfile(
      id: id,
      name: trimmed,
      databaseName: 'bookmark_app_profile_$id',
      directoryPath: directory.path,
    );
    _state = ProfileState(
      profiles: [..._state.profiles, profile],
      activeProfileId: _state.activeProfileId,
    );
    await _writeProfileMetadata(profile);
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
              ? candidate.copyWith(name: trimmed)
              : candidate)
          .toList(),
      activeProfileId: _state.activeProfileId,
    );
    final updated = _state.profiles.firstWhere((candidate) => candidate.id == profile.id);
    await _writeProfileMetadata(updated);
    await _save();
  }

  Future<void> _writeProfileMetadata(DatabaseProfile profile) async {
    final file = File(profile.profileMetadataPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'id': profile.id,
        'name': profile.name,
        'database': 'database.sqlite',
        'photos': 'photos',
      }),
      flush: true,
    );
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
