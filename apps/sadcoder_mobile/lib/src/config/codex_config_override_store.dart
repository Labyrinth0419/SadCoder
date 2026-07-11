import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'codex_config_override_controller.dart';
import 'codex_config_overrides.dart';

abstract interface class CodexConfigOverrideStore {
  Future<CodexConfigOverrides> loadAppDefaults();

  Future<void> saveAppDefaults(CodexConfigOverrides overrides);
}

class SharedPreferencesCodexConfigOverrideStore
    implements CodexConfigOverrideStore {
  const SharedPreferencesCodexConfigOverrideStore({
    this.preferencesProvider = SharedPreferences.getInstance,
  });

  static const _appDefaultsKey = 'codex.config.appDefaults.v1';

  final Future<SharedPreferences> Function() preferencesProvider;

  @override
  Future<CodexConfigOverrides> loadAppDefaults() async {
    final preferences = await preferencesProvider();
    final raw = preferences.getString(_appDefaultsKey);
    if (raw == null || raw.trim().isEmpty) {
      return CodexConfigOverrides.empty;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return _overridesFromJson(_stringKeyedMap(decoded));
      }
    } on FormatException {
      return CodexConfigOverrides.empty;
    }
    return CodexConfigOverrides.empty;
  }

  @override
  Future<void> saveAppDefaults(CodexConfigOverrides overrides) async {
    final preferences = await preferencesProvider();
    await preferences.setString(
      _appDefaultsKey,
      jsonEncode(_overridesToJson(overrides)),
    );
  }
}

class PersistedCodexConfigOverrideController
    extends CodexConfigOverrideController {
  PersistedCodexConfigOverrideController._({
    required CodexConfigOverrideStore store,
    required CodexConfigOverrides appDefault,
  }) : _store = store,
       super(initialLayers: CodexConfigOverrideLayers(appDefault: appDefault));

  static Future<PersistedCodexConfigOverrideController> load({
    CodexConfigOverrideStore store =
        const SharedPreferencesCodexConfigOverrideStore(),
  }) async {
    final appDefault = await store.loadAppDefaults();
    return PersistedCodexConfigOverrideController._(
      store: store,
      appDefault: appDefault,
    );
  }

  final CodexConfigOverrideStore _store;

  @override
  void setAppDefault(CodexConfigOverrides overrides) {
    final previous = _overridesToJson(layers.appDefault);
    super.setAppDefault(overrides);
    if (!_mapsEqual(previous, _overridesToJson(layers.appDefault))) {
      _persist();
    }
  }

  void _persist() {
    try {
      unawaited(
        _store.saveAppDefaults(layers.appDefault).catchError((Object _) {}),
      );
    } on Object {
      // App default overrides should remain usable even if persistence fails.
    }
  }
}

Map<String, Object?> _overridesToJson(CodexConfigOverrides overrides) {
  final json = <String, Object?>{};
  _putString(json, 'model', overrides.model);
  _putString(json, 'effort', overrides.effort);
  _putString(json, 'summary', overrides.summary);
  if (_hasObjectValue(overrides.approvalPolicy)) {
    json['approvalPolicy'] = overrides.approvalPolicy;
  }
  final permissionProfile = _stringValue(overrides.permissionProfile);
  if (permissionProfile != null) {
    json['permissionProfile'] = permissionProfile;
  } else {
    final sandboxPolicy = _optionalStringKeyedMap(overrides.sandboxPolicy);
    if (sandboxPolicy != null) {
      json['sandboxPolicy'] = sandboxPolicy;
    }
  }
  _putString(json, 'cwd', overrides.cwd);
  _putString(json, 'personality', overrides.personality);
  _putString(json, 'serviceTier', overrides.serviceTier);
  final collaborationMode = overrides.collaborationMode?.toJson();
  if (collaborationMode != null) {
    json['collaborationMode'] = collaborationMode;
  }
  return json;
}

CodexConfigOverrides _overridesFromJson(Map<String, Object?> json) {
  return CodexConfigOverrides(
    model: _stringValue(json['model']),
    effort: _stringValue(json['effort']),
    summary: _stringValue(json['summary']),
    approvalPolicy: json['approvalPolicy'],
    sandboxPolicy: _optionalStringKeyedMap(json['sandboxPolicy']),
    permissionProfile:
        _stringValue(json['permissionProfile']) ??
        _stringValue(json['permissions']),
    cwd: _stringValue(json['cwd']),
    personality: _stringValue(json['personality']),
    serviceTier: _stringValue(json['serviceTier']),
    collaborationMode: _collaborationModeFromJson(
      _optionalStringKeyedMap(json['collaborationMode']),
    ),
  );
}

CodexCollaborationModeOverride? _collaborationModeFromJson(
  Map<String, Object?>? json,
) {
  if (json == null || json.isEmpty) {
    return null;
  }
  final settings = _stringKeyedMap(json['settings']);
  final mode = _stringValue(json['mode']);
  final model = _stringValue(settings['model']);
  if (mode == null || model == null) {
    return null;
  }
  return CodexCollaborationModeOverride(
    mode: mode,
    model: model,
    reasoningEffort: _stringValue(settings['reasoning_effort']),
    developerInstructions: _stringValue(settings['developer_instructions']),
  );
}

void _putString(Map<String, Object?> json, String key, String? value) {
  final normalized = _stringValue(value);
  if (normalized != null) {
    json[key] = normalized;
  }
}

Map<String, Object?> _stringKeyedMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

Map<String, Object?>? _optionalStringKeyedMap(Object? value) {
  final map = _stringKeyedMap(value);
  return map.isEmpty ? null : map;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool _hasObjectValue(Object? value) {
  return switch (value) {
    null => false,
    String text => _stringValue(text) != null,
    Map map => map.isNotEmpty,
    _ => true,
  };
}

bool _mapsEqual(Map<String, Object?> left, Map<String, Object?> right) {
  return jsonEncode(left) == jsonEncode(right);
}
