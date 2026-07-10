abstract interface class HookListReader {
  Future<HookListPage> listHooks({List<String> cwds = const []});
}

class HookListPage {
  const HookListPage({required this.entries});

  factory HookListPage.fromJson(Map<String, Object?> json) {
    return HookListPage(
      entries: _list(
        json['data'],
      ).map(HookListEntry.fromJson).nonNulls.toList(growable: false),
    );
  }

  final List<HookListEntry> entries;
}

class HookListEntry {
  const HookListEntry({
    required this.cwd,
    required this.hooks,
    required this.warnings,
    required this.errors,
    required this.raw,
  });

  static HookListEntry? fromJson(Object? value) {
    final map = _objectMap(value);
    final cwd = _stringValue(map['cwd']);
    if (cwd == null) {
      return null;
    }
    return HookListEntry(
      cwd: cwd,
      hooks: _list(
        map['hooks'],
      ).map(HookSummary.fromJson).nonNulls.toList(growable: false),
      warnings: _stringList(map['warnings']),
      errors: _list(
        map['errors'],
      ).map(HookLoadError.fromJson).nonNulls.toList(growable: false),
      raw: map,
    );
  }

  final String cwd;
  final List<HookSummary> hooks;
  final List<String> warnings;
  final List<HookLoadError> errors;
  final Map<String, Object?> raw;
}

class HookSummary {
  const HookSummary({
    required this.key,
    required this.eventName,
    required this.handlerType,
    required this.timeoutSec,
    required this.sourcePath,
    required this.source,
    required this.displayOrder,
    required this.enabled,
    required this.isManaged,
    required this.currentHash,
    required this.trustStatus,
    required this.raw,
    this.matcher,
    this.command,
    this.statusMessage,
    this.pluginId,
  });

  static HookSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    final key = _stringValue(map['key']);
    if (key == null) {
      return null;
    }
    return HookSummary(
      key: key,
      eventName: _stringField(map, ['eventName', 'event_name']) ?? 'unknown',
      handlerType:
          _stringField(map, ['handlerType', 'handler_type']) ?? 'unknown',
      matcher: _stringValue(map['matcher']),
      command: _stringValue(map['command']),
      timeoutSec: _intField(map, ['timeoutSec', 'timeout_sec']) ?? 0,
      statusMessage: _stringField(map, ['statusMessage', 'status_message']),
      sourcePath: _stringField(map, ['sourcePath', 'source_path']) ?? '',
      source: _stringValue(map['source']) ?? 'unknown',
      pluginId: _stringField(map, ['pluginId', 'plugin_id']),
      displayOrder: _intField(map, ['displayOrder', 'display_order']) ?? 0,
      enabled: _boolValue(map['enabled']) ?? true,
      isManaged: _boolField(map, ['isManaged', 'is_managed']) ?? false,
      currentHash: _stringField(map, ['currentHash', 'current_hash']) ?? '',
      trustStatus:
          _stringField(map, ['trustStatus', 'trust_status']) ?? 'unknown',
      raw: map,
    );
  }

  final String key;
  final String eventName;
  final String handlerType;
  final String? matcher;
  final String? command;
  final int timeoutSec;
  final String? statusMessage;
  final String sourcePath;
  final String source;
  final String? pluginId;
  final int displayOrder;
  final bool enabled;
  final bool isManaged;
  final String currentHash;
  final String trustStatus;
  final Map<String, Object?> raw;
}

class HookLoadError {
  const HookLoadError({required this.path, required this.message});

  static HookLoadError? fromJson(Object? value) {
    final map = _objectMap(value);
    final path = _stringValue(map['path']);
    final message = _stringValue(map['message']);
    if (path == null || message == null) {
      return null;
    }
    return HookLoadError(path: path, message: message);
  }

  final String path;
  final String message;
}

List<Object?> _list(Object? value) {
  return value is List ? value : const [];
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String? _stringField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _stringValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

bool? _boolValue(Object? value) => value is bool ? value : null;

bool? _boolField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _boolValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

int? _intField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _intValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(
    value
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty),
  );
}
