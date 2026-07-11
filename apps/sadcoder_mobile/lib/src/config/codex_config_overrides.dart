enum CodexConfigOverrideSource { serverDefault, appDefault, session, turn }

class CodexConfigOverrides {
  const CodexConfigOverrides({
    this.model,
    this.effort,
    this.summary,
    this.approvalPolicy,
    this.sandboxPolicy,
    this.permissionProfile,
    this.cwd,
    this.personality,
    this.serviceTier,
    this.collaborationMode,
  });

  static const empty = CodexConfigOverrides();

  final String? model;
  final String? effort;
  final String? summary;
  final Object? approvalPolicy;
  final Map<String, Object?>? sandboxPolicy;
  final String? permissionProfile;
  final String? cwd;
  final String? personality;
  final String? serviceTier;
  final CodexCollaborationModeOverride? collaborationMode;

  bool get isEmpty => toTurnStartParams().isEmpty;

  CodexConfigOverrides merge(CodexConfigOverrides higherPriority) {
    final higherHasPermissionProfile = _hasText(
      higherPriority.permissionProfile,
    );
    final higherHasSandboxPolicy =
        !higherHasPermissionProfile && _hasMap(higherPriority.sandboxPolicy);
    return CodexConfigOverrides(
      model: _stringOverride(model, higherPriority.model),
      effort: _stringOverride(effort, higherPriority.effort),
      summary: _stringOverride(summary, higherPriority.summary),
      approvalPolicy: _objectOverride(
        approvalPolicy,
        higherPriority.approvalPolicy,
      ),
      sandboxPolicy: higherHasPermissionProfile
          ? null
          : _mapOverride(sandboxPolicy, higherPriority.sandboxPolicy),
      permissionProfile: higherHasSandboxPolicy
          ? null
          : _stringOverride(
              permissionProfile,
              higherPriority.permissionProfile,
            ),
      cwd: _stringOverride(cwd, higherPriority.cwd),
      personality: _stringOverride(personality, higherPriority.personality),
      serviceTier: _stringOverride(serviceTier, higherPriority.serviceTier),
      collaborationMode: _collaborationModeOverride(
        collaborationMode,
        higherPriority.collaborationMode,
      ),
    );
  }

  Map<String, Object?> toTurnStartParams() {
    final collaborationModeJson = collaborationMode?.toJson();
    final hasCollaborationMode = collaborationModeJson != null;
    return {
      if (!hasCollaborationMode && _hasText(model)) 'model': model,
      if (!hasCollaborationMode && _hasText(effort)) 'effort': effort,
      if (_hasText(summary)) 'summary': summary,
      if (_hasObjectOverride(approvalPolicy)) 'approvalPolicy': approvalPolicy,
      if (_hasText(permissionProfile)) 'permissions': permissionProfile!.trim(),
      if (!_hasText(permissionProfile) && _hasMap(sandboxPolicy))
        'sandboxPolicy': sandboxPolicy,
      if (_hasText(cwd)) 'cwd': cwd,
      if (_hasText(personality)) 'personality': personality,
      if (_hasText(serviceTier)) 'serviceTier': serviceTier,
      if (hasCollaborationMode) 'collaborationMode': collaborationModeJson,
    };
  }

  Map<String, Object?> toThreadSettingsUpdateParams({
    bool includeClears = false,
  }) {
    final collaborationModeJson = collaborationMode?.toJson();
    final hasCollaborationMode = collaborationModeJson != null;
    return {
      if (!hasCollaborationMode &&
          _shouldIncludeUpdateString(model, includeClears))
        'model': _updateStringValue(model),
      if (!hasCollaborationMode &&
          _shouldIncludeUpdateString(effort, includeClears))
        'effort': _updateStringValue(effort),
      if (_shouldIncludeUpdateString(summary, includeClears))
        'summary': _updateStringValue(summary),
      if (_shouldIncludeUpdateObject(approvalPolicy, includeClears))
        'approvalPolicy': _updateObjectValue(approvalPolicy),
      if (_shouldIncludeUpdateString(permissionProfile, includeClears))
        'permissions': _updateStringValue(permissionProfile),
      if (!_hasText(permissionProfile) &&
          _shouldIncludeUpdateMap(sandboxPolicy, includeClears))
        'sandboxPolicy': _updateMapValue(sandboxPolicy),
      if (_shouldIncludeUpdateString(cwd, includeClears))
        'cwd': _updateStringValue(cwd),
      if (_shouldIncludeUpdateString(personality, includeClears))
        'personality': _updateStringValue(personality),
      if (_shouldIncludeUpdateString(serviceTier, includeClears))
        'serviceTier': _updateStringValue(serviceTier),
      if (hasCollaborationMode) 'collaborationMode': collaborationModeJson,
    };
  }
}

class CodexCollaborationModeOverride {
  const CodexCollaborationModeOverride({
    required this.mode,
    required this.model,
    this.reasoningEffort,
    this.developerInstructions,
  });

  factory CodexCollaborationModeOverride.plan({required String model}) {
    return CodexCollaborationModeOverride(
      mode: 'plan',
      model: model,
      reasoningEffort: 'medium',
    );
  }

  final String mode;
  final String model;
  final String? reasoningEffort;
  final String? developerInstructions;

  String? get displayLabel {
    final normalizedMode = _normalizeText(mode);
    if (normalizedMode == null) {
      return null;
    }
    final normalizedEffort = _normalizeText(reasoningEffort);
    return normalizedEffort == null
        ? normalizedMode
        : '$normalizedMode / $normalizedEffort';
  }

  Map<String, Object?>? toJson() {
    final normalizedMode = _normalizeText(mode);
    final normalizedModel = _normalizeText(model);
    if (normalizedMode == null || normalizedModel == null) {
      return null;
    }
    return {
      'mode': normalizedMode,
      'settings': {
        'model': normalizedModel,
        'reasoning_effort': _normalizeText(reasoningEffort),
        'developer_instructions': developerInstructions,
      },
    };
  }
}

class CodexConfigOverrideLayers {
  const CodexConfigOverrideLayers({
    this.appDefault = CodexConfigOverrides.empty,
    this.session = CodexConfigOverrides.empty,
    this.turn = CodexConfigOverrides.empty,
  });

  final CodexConfigOverrides appDefault;
  final CodexConfigOverrides session;
  final CodexConfigOverrides turn;

  CodexConfigOverrides resolve() {
    return CodexConfigOverrides.empty
        .merge(appDefault)
        .merge(session)
        .merge(turn);
  }

  CodexConfigOverrideSource sourceFor(String fieldName) {
    final resolved = resolve();
    if (fieldName == 'permissionProfile' &&
        !_hasText(resolved.permissionProfile)) {
      return CodexConfigOverrideSource.serverDefault;
    }
    if (fieldName == 'sandboxPolicy' && !_hasMap(resolved.sandboxPolicy)) {
      return CodexConfigOverrideSource.serverDefault;
    }
    if (fieldName == 'collaborationMode' &&
        resolved.collaborationMode?.toJson() == null) {
      return CodexConfigOverrideSource.serverDefault;
    }
    final wireFieldName = fieldName == 'permissionProfile'
        ? 'permissions'
        : fieldName;
    if (turn.toTurnStartParams().containsKey(wireFieldName)) {
      return CodexConfigOverrideSource.turn;
    }
    if (session.toTurnStartParams().containsKey(wireFieldName)) {
      return CodexConfigOverrideSource.session;
    }
    if (appDefault.toTurnStartParams().containsKey(wireFieldName)) {
      return CodexConfigOverrideSource.appDefault;
    }
    return CodexConfigOverrideSource.serverDefault;
  }
}

typedef CodexConfigOverrideLayersProvider =
    CodexConfigOverrideLayers Function();

String? _stringOverride(String? lowerPriority, String? higherPriority) {
  if (_hasText(higherPriority)) {
    return higherPriority!.trim();
  }
  if (_hasText(lowerPriority)) {
    return lowerPriority!.trim();
  }
  return null;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

Object? _objectOverride(Object? lowerPriority, Object? higherPriority) {
  if (_hasObjectOverride(higherPriority)) {
    return higherPriority;
  }
  if (_hasObjectOverride(lowerPriority)) {
    return lowerPriority;
  }
  return null;
}

Map<String, Object?>? _mapOverride(
  Map<String, Object?>? lowerPriority,
  Map<String, Object?>? higherPriority,
) {
  if (_hasMap(higherPriority)) {
    return higherPriority;
  }
  if (_hasMap(lowerPriority)) {
    return lowerPriority;
  }
  return null;
}

bool _hasObjectOverride(Object? value) {
  return switch (value) {
    null => false,
    String text => _hasText(text),
    Map map => map.isNotEmpty,
    _ => true,
  };
}

bool _hasMap(Map<String, Object?>? value) => value != null && value.isNotEmpty;

bool _shouldIncludeUpdateString(String? value, bool includeClears) {
  if (value == null) {
    return false;
  }
  return value.trim().isNotEmpty || includeClears;
}

String? _updateStringValue(String? value) {
  if (!_hasText(value)) {
    return null;
  }
  return value!.trim();
}

bool _shouldIncludeUpdateObject(Object? value, bool includeClears) {
  if (value == null) {
    return false;
  }
  return switch (value) {
    String text => text.trim().isNotEmpty || includeClears,
    Map map => map.isNotEmpty || includeClears,
    _ => true,
  };
}

Object? _updateObjectValue(Object? value) {
  return switch (value) {
    null => null,
    String text => _hasText(text) ? text.trim() : null,
    Map map => map.isEmpty ? null : value,
    _ => value,
  };
}

bool _shouldIncludeUpdateMap(Map<String, Object?>? value, bool includeClears) {
  if (value == null) {
    return false;
  }
  return value.isNotEmpty || includeClears;
}

Map<String, Object?>? _updateMapValue(Map<String, Object?>? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

CodexCollaborationModeOverride? _collaborationModeOverride(
  CodexCollaborationModeOverride? lowerPriority,
  CodexCollaborationModeOverride? higherPriority,
) {
  if (higherPriority?.toJson() != null) {
    return higherPriority;
  }
  if (lowerPriority?.toJson() != null) {
    return lowerPriority;
  }
  return null;
}

String? _normalizeText(String? value) {
  if (!_hasText(value)) {
    return null;
  }
  return value!.trim();
}
