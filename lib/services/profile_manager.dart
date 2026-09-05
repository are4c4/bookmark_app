import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import 'profile_backup_service.dart';

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

  DatabaseProfile copyWith({String? name, String? databaseName, String? directoryPath}) => DatabaseProfile(
        id: id,
        name: name ?? this.name,
        databaseName: databaseName ?? this.databaseName,
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
  ProfileManager._(this._file, this._documentsRoot, this._profilesRoot, this._state);

  final File _file;
  final Directory _documentsRoot;
  final Directory _profilesRoot;
  ProfileState _state;

  ProfileState get state => _state;

  static void _debugFallbackFailure(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    assert(() {
      stderr.writeln('ProfileManager: $operation failed; using fallback: $error');
      stderr.writeln(stackTrace);
      return true;
    }());
  }

  static Future<ProfileManager> load() async {
    final support = await getApplicationSupportDirectory();
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory('${documents.path}/BookmarkApp/Profiles');
    await root.create(recursive: true);
    final file = File('${support.path}/bookmark_profiles.json');

    ProfileState state;
    if (!await file.exists()) {
      state = ProfileState(
        profiles: [
          DatabaseProfile(
            id: 'default',
            name: 'Default',
            databaseName: 'BookmarkApp/Profiles/default/database',
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
              directoryPath: '',
            ),
          ];
        }

        profiles = profiles.map((profile) {
          return profile.copyWith(
            databaseName: 'BookmarkApp/Profiles/${profile.id}/database',
            directoryPath: '${root.path}/${profile.id}',
          );
        }).toList();

        final requestedActive = raw['activeProfileId'] as String? ?? 'default';
        final active = profiles.any((profile) => profile.id == requestedActive)
            ? requestedActive
            : profiles.first.id;
        state = ProfileState(profiles: profiles, activeProfileId: active);
      } catch (error, stackTrace) {
        // Existing installations intentionally fail soft to the default profile,
        // but preserve the cause in debug/assert builds so corrupt profile
        // metadata or data-location regressions are not completely silent.
        _debugFallbackFailure('profile state load', error, stackTrace);
        state = ProfileState(
          profiles: [
            DatabaseProfile(
              id: 'default',
              name: 'Default',
              databaseName: 'BookmarkApp/Profiles/default/database',
              directoryPath: '${root.path}/default',
            ),
          ],
          activeProfileId: 'default',
        );
      }
    }

    final manager = ProfileManager._(file, documents, root, state);
    await manager._prepareProfileFolders();
    await manager._save();
    return manager;
  }

  String _legacyDatabaseName(DatabaseProfile profile) =>
      profile.isDefault ? 'bookmark_app' : 'bookmark_app_profile_${profile.id}';

  Future<void> _prepareProfileFolders() async {
    for (final profile in _state.profiles) {
      final directory = Directory(profile.directoryPath);
      final photos = Directory(profile.photoDirectoryPath);
      await directory.create(recursive: true);
      await photos.create(recursive: true);

      final targetDb = File(profile.databasePath);
      if (!await targetDb.exists()) {
        final legacyDb = File('${_documentsRoot.path}/${_legacyDatabaseName(profile)}.sqlite');
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
      databaseName: 'BookmarkApp/Profiles/$id/database',
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

  Future<void> _copyDirectoryContents(
    Directory source,
    Directory target,
  ) async {
    if (!await source.exists()) return;
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = entity.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      if (entity is Directory) {
        await _copyDirectoryContents(entity, Directory('${target.path}/$name'));
      } else if (entity is File) {
        await entity.copy('${target.path}/$name');
      }
    }
  }

  String? _pathInsideCopy(
    String originalPath,
    DatabaseProfile source,
    DatabaseProfile copy,
  ) {
    final normalized = originalPath.replaceAll('\\', '/');
    final sourceRoot =
        source.directoryPath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    if (!normalized.startsWith('$sourceRoot/')) return null;
    return '${copy.directoryPath}/${normalized.substring(sourceRoot.length + 1)}';
  }

  Future<void> _rewriteCopiedPaths(
    DatabaseProfile source,
    DatabaseProfile copy,
  ) async {
    final database = AppDatabase(
      databaseName: copy.databaseName,
      profileDirectoryPath: copy.directoryPath,
    );
    try {
      final photos = await database.select(database.photos).get();
      for (final photo in photos) {
        final copiedPath = _pathInsideCopy(photo.path, source, copy);
        if (copiedPath == null || !await File(copiedPath).exists()) continue;
        await (database.update(database.photos)
              ..where((row) => row.id.equals(photo.id)))
            .write(PhotosCompanion(path: Value(database.toStoredPath(copiedPath))));
      }

      final attachments =
          await database.select(database.bookmarkAttachments).get();
      for (final attachment in attachments) {
        final copiedPath = _pathInsideCopy(attachment.path, source, copy);
        if (copiedPath == null || !await File(copiedPath).exists()) continue;
        await (database.update(database.bookmarkAttachments)
              ..where((row) => row.id.equals(attachment.id)))
            .write(BookmarkAttachmentsCompanion(
              path: Value(database.toStoredPath(copiedPath)),
            ));
      }
    } finally {
      await database.close();
    }
  }

  Future<DatabaseProfile> duplicateProfile(
    DatabaseProfile source, {
    String? name,
  }) async {
    final copy = await createProfile(
      name?.trim().isNotEmpty == true ? name!.trim() : '${source.name} copy',
    );

    try {
      final sourceDb = File(source.databasePath);
      if (await sourceDb.exists()) {
        await sourceDb.copy(copy.databasePath);
      }
      for (final suffix in const ['-wal', '-shm']) {
        final sidecar = File('${source.databasePath}$suffix');
        if (await sidecar.exists()) {
          await sidecar.copy('${copy.databasePath}$suffix');
        }
      }

      await _copyDirectoryContents(
        Directory(source.photoDirectoryPath),
        Directory(copy.photoDirectoryPath),
      );
      await _copyDirectoryContents(
        Directory('${source.directoryPath}/attachments'),
        Directory('${copy.directoryPath}/attachments'),
      );

      if (await File(copy.databasePath).exists()) {
        await _rewriteCopiedPaths(source, copy);
      }
      await _writeProfileMetadata(copy);
      return copy;
    } catch (_) {
      await deleteProfile(copy);
      rethrow;
    }
  }

  Future<DatabaseProfile> importProfileBackup(
    String archivePath, {
    required String name,
  }) async {
    final copy = await createProfile(name);
    try {
      await const ProfileBackupService().restoreProfile(
        archivePath: archivePath,
        targetDirectoryPath: copy.directoryPath,
      );

      DatabaseProfile? sourceProfile;
      final importedMetadata = File(copy.profileMetadataPath);
      if (await importedMetadata.exists()) {
        try {
          final raw = jsonDecode(await importedMetadata.readAsString());
          if (raw is Map) {
            sourceProfile = DatabaseProfile.fromJson(
              Map<String, Object?>.from(raw),
            );
          }
        } catch (error, stackTrace) {
          // Backup metadata is advisory for path rewriting. The restored profile
          // remains usable without it, so keep the import best-effort while
          // exposing malformed metadata during development.
          _debugFallbackFailure('imported profile metadata read', error, stackTrace);
          sourceProfile = null;
        }
      }
      if (sourceProfile != null) {
        await _rewriteCopiedPaths(sourceProfile, copy);
      }

      await _writeProfileMetadata(copy);
      await _save();
      return copy;
    } catch (_) {
      await deleteProfile(copy);
      rethrow;
    }
  }

  Future<void> deleteProfile(DatabaseProfile profile) async {
    if (profile.isDefault) throw StateError('Default profile cannot be deleted');
    if (_state.profiles.length <= 1) throw StateError('At least one profile is required');
    if (_state.activeProfileId == profile.id) {
      throw StateError('Switch to another profile before deleting the active profile');
    }
    _state = ProfileState(
      profiles: _state.profiles.where((candidate) => candidate.id != profile.id).toList(),
      activeProfileId: _state.activeProfileId,
    );
    await _save();
    final directory = Directory(profile.directoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
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
