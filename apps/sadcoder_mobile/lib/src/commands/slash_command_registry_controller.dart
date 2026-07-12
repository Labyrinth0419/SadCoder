import 'package:flutter/foundation.dart';

import '../ssh/ssh_profile.dart';
import 'slash_command_manifest_reader.dart';
import 'slash_command_manifest_store.dart';
import 'slash_command_registry.dart';

enum SlashCommandRegistryLoadStatus { builtIn, loading, loaded, cached, failed }

class SlashCommandRegistryController extends ChangeNotifier {
  SlashCommandRegistryController({
    required SlashCommandManifestReader? Function() readerProvider,
    SlashCommandManifestStore? cacheStore,
    String? Function()? cwdProvider,
  }) : _readerProvider = readerProvider,
       _cacheStore = cacheStore,
       _cwdProvider = cwdProvider;

  final SlashCommandManifestReader? Function() _readerProvider;
  final SlashCommandManifestStore? _cacheStore;
  final String? Function()? _cwdProvider;

  SlashCommandRegistry _registry = const SlashCommandRegistry();
  SlashCommandManifest? _manifest;
  SlashCommandRegistryLoadStatus _status =
      SlashCommandRegistryLoadStatus.builtIn;
  Object? _error;
  String? _profileId;
  int _generation = 0;
  Future<void>? _pendingRefresh;

  SlashCommandRegistry get registry => _registry;

  SlashCommandManifest? get manifest => _manifest;

  SlashCommandRegistryLoadStatus get status => _status;

  Object? get error => _error;

  Future<void> refresh(SshProfile profile) {
    final reader = _readerProvider();
    if (reader == null) {
      reset();
      return Future.value();
    }

    if (_profileId == profile.id) {
      if (_status == SlashCommandRegistryLoadStatus.loaded) {
        return Future.value();
      }
      final pendingRefresh = _pendingRefresh;
      if (_status == SlashCommandRegistryLoadStatus.loading &&
          pendingRefresh != null) {
        return pendingRefresh;
      }
    }

    final generation = ++_generation;
    _profileId = profile.id;
    _manifest = null;
    _registry = const SlashCommandRegistry();
    _status = SlashCommandRegistryLoadStatus.loading;
    _error = null;
    notifyListeners();

    final pendingRefresh = _refresh(reader, profile, generation);
    _pendingRefresh = pendingRefresh;
    return pendingRefresh;
  }

  void reset() {
    _generation++;
    _pendingRefresh = null;
    _profileId = null;
    _manifest = null;
    _error = null;
    _registry = const SlashCommandRegistry();
    _status = SlashCommandRegistryLoadStatus.builtIn;
    notifyListeners();
  }

  Future<void> _refresh(
    SlashCommandManifestReader reader,
    SshProfile profile,
    int generation,
  ) async {
    try {
      final manifest = await reader.readSlashCommands(profile);
      if (!_isCurrent(generation)) {
        return;
      }
      if (manifest.commands.isEmpty) {
        throw const FormatException('Slash command manifest is empty.');
      }
      _manifest = manifest;
      _registry = manifest.asRegistry();
      _status = SlashCommandRegistryLoadStatus.loaded;
      _error = null;
      await _saveCachedManifest(profile, manifest);
    } on Object catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      final cachedManifest = await _loadCachedManifest(profile);
      if (!_isCurrent(generation)) {
        return;
      }
      if (cachedManifest != null && cachedManifest.commands.isNotEmpty) {
        _manifest = cachedManifest;
        _registry = cachedManifest.asRegistry();
        _status = SlashCommandRegistryLoadStatus.cached;
        _error = error;
      } else {
        _manifest = null;
        _registry = const SlashCommandRegistry();
        _status = SlashCommandRegistryLoadStatus.failed;
        _error = error;
      }
    } finally {
      if (_isCurrent(generation)) {
        _pendingRefresh = null;
        notifyListeners();
      }
    }
  }

  Future<void> _saveCachedManifest(
    SshProfile profile,
    SlashCommandManifest manifest,
  ) async {
    final cacheStore = _cacheStore;
    if (cacheStore == null) {
      return;
    }
    try {
      await cacheStore.saveManifest(
        profileId: profile.id,
        cwd: _cwdProvider?.call(),
        manifest: manifest,
        cachedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    } on Object {
      // Slash command manifest cache is reconnect-only state.
    }
  }

  Future<SlashCommandManifest?> _loadCachedManifest(SshProfile profile) async {
    final cacheStore = _cacheStore;
    if (cacheStore == null) {
      return null;
    }
    try {
      return await cacheStore.loadManifest(
        profileId: profile.id,
        cwd: _cwdProvider?.call(),
      );
    } on Object {
      return null;
    }
  }

  bool _isCurrent(int generation) => _generation == generation;
}
