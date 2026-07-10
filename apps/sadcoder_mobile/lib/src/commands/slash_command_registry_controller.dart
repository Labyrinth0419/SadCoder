import 'package:flutter/foundation.dart';

import '../ssh/ssh_profile.dart';
import 'slash_command_manifest_reader.dart';
import 'slash_command_registry.dart';

enum SlashCommandRegistryLoadStatus { builtIn, loading, loaded, failed }

class SlashCommandRegistryController extends ChangeNotifier {
  SlashCommandRegistryController({
    required SlashCommandManifestReader? Function() readerProvider,
  }) : _readerProvider = readerProvider;

  final SlashCommandManifestReader? Function() _readerProvider;

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
    } on Object catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      _manifest = null;
      _registry = const SlashCommandRegistry();
      _status = SlashCommandRegistryLoadStatus.failed;
      _error = error;
    } finally {
      if (_isCurrent(generation)) {
        _pendingRefresh = null;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(int generation) => _generation == generation;
}
