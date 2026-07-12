import '../../config/codex_config_snapshot.dart';
import '../../config/codex_config_snapshot_controller.dart';
import '../../i18n/app_localizations.dart';

String buildMemoriesSummary({
  required AppLocalizations l10n,
  required CodexConfigSnapshotController? controller,
  required Map<String, Object?> threadRaw,
}) {
  final lines = <String>[l10n.memoriesTitle];
  lines.add(
    '${l10n.memoriesThreadMode}: '
    '${_threadMemoryMode(threadRaw) ?? l10n.memoriesUnknownThreadMode}',
  );

  if (controller == null) {
    lines.add(l10n.memoriesUnavailable);
    return lines.join('\n');
  }
  if (controller.status == CodexConfigSnapshotStatus.failed) {
    final error = controller.error;
    lines.add('${l10n.memoriesLoadFailed}${error == null ? '' : ': $error'}');
    return lines.join('\n');
  }

  final snapshot = controller.snapshot;
  if (snapshot == null) {
    lines.add(l10n.memoriesNoSnapshot);
    return lines.join('\n');
  }

  lines.add(l10n.memoriesConfigValues);
  final entries = _memoryConfigEntries(snapshot)..sort(_compareConfigEntries);
  if (entries.isEmpty) {
    lines.add('  ${l10n.memoriesNoConfigValues}');
  } else {
    for (final entry in entries) {
      final value = displayConfigValue(entry.value) ?? l10n.serverValueUnset;
      final origin = entry.origin ?? l10n.sourceServerDefault;
      lines.add('  ${entry.label}: $value (${l10n.overrideSource}: $origin)');
    }
  }

  return lines.join('\n');
}

List<_MemoryConfigEntry> _memoryConfigEntries(CodexConfigSnapshot snapshot) {
  final entries = <_MemoryConfigEntry>[];
  final config = snapshot.config;

  final memories = _objectMap(config['memories']);
  for (final entry in memories.entries) {
    if (_isMemorySettingKey(entry.key)) {
      entries.add(
        _MemoryConfigEntry(
          label: entry.key,
          value: entry.value,
          origin:
              snapshot.originLabelFor('memories.${entry.key}') ??
              snapshot.originLabelFor('memories'),
        ),
      );
    }
  }

  final features = _objectMap(config['features']);
  for (final entry in features.entries) {
    if (_isMemoryFeatureKey(entry.key)) {
      entries.add(
        _MemoryConfigEntry(
          label: 'features.${entry.key}',
          value: entry.value,
          origin:
              snapshot.originLabelFor('features.${entry.key}') ??
              snapshot.originLabelFor('features'),
        ),
      );
    }
  }

  for (final entry in config.entries) {
    final key = entry.key.trim();
    if (_isNestedMemoryConfigKey(key)) {
      entries.add(
        _MemoryConfigEntry(
          label: key.substring('memories.'.length),
          value: entry.value,
          origin:
              snapshot.originLabelFor(key) ??
              snapshot.originLabelFor('memories'),
        ),
      );
    } else if (_isTopLevelMemoryConfigKey(key)) {
      entries.add(
        _MemoryConfigEntry(
          label: key,
          value: entry.value,
          origin: snapshot.originLabelFor(key),
        ),
      );
    } else if (_isFlatMemoryFeatureKey(key)) {
      entries.add(
        _MemoryConfigEntry(
          label: key,
          value: entry.value,
          origin:
              snapshot.originLabelFor(key) ??
              snapshot.originLabelFor('features'),
        ),
      );
    }
  }

  return _dedupeEntries(entries);
}

List<_MemoryConfigEntry> _dedupeEntries(List<_MemoryConfigEntry> entries) {
  final seen = <String>{};
  final deduped = <_MemoryConfigEntry>[];
  for (final entry in entries) {
    if (seen.add(entry.label)) {
      deduped.add(entry);
    }
  }
  return deduped;
}

int _compareConfigEntries(_MemoryConfigEntry left, _MemoryConfigEntry right) =>
    left.label.compareTo(right.label);

bool _isNestedMemoryConfigKey(String key) {
  if (!key.startsWith('memories.')) {
    return false;
  }
  return _isMemorySettingKey(key.substring('memories.'.length));
}

bool _isTopLevelMemoryConfigKey(String key) {
  return key == 'memory_tool' || key == 'memoryTool';
}

bool _isFlatMemoryFeatureKey(String key) {
  return key == 'features.memories' ||
      key == 'features.memory_tool' ||
      key == 'features.memoryTool' ||
      key == 'feature_flags.memories' ||
      key == 'featureFlags.memories';
}

bool _isMemorySettingKey(String key) {
  return switch (key) {
    'consolidation_model' ||
    'dedicated_tools' ||
    'disable_on_external_context' ||
    'extract_model' ||
    'generate_memories' ||
    'max_raw_memories_for_consolidation' ||
    'max_rollout_age_days' ||
    'max_rollouts_per_startup' ||
    'max_unused_days' ||
    'min_rate_limit_remaining_percent' ||
    'min_rollout_idle_hours' ||
    'use_memories' => true,
    _ => false,
  };
}

bool _isMemoryFeatureKey(String key) {
  return key == 'memories' || key == 'memory_tool' || key == 'memoryTool';
}

String? _threadMemoryMode(Map<String, Object?> raw) {
  final direct =
      _stringValue(raw['memoryMode']) ?? _stringValue(raw['memory_mode']);
  if (direct != null) {
    return direct;
  }
  final memory = raw['memory'];
  if (memory is String && memory.trim().isNotEmpty) {
    return memory.trim();
  }
  final memoryMap = _objectMap(memory);
  return _stringValue(memoryMap['mode']) ??
      _stringValue(memoryMap['memoryMode']) ??
      _stringValue(memoryMap['memory_mode']);
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

class _MemoryConfigEntry {
  const _MemoryConfigEntry({
    required this.label,
    required this.value,
    required this.origin,
  });

  final String label;
  final Object? value;
  final String? origin;
}
