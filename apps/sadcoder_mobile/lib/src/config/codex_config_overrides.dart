enum CodexConfigOverrideSource { serverDefault, appDefault, session, turn }

class CodexConfigOverrides {
  const CodexConfigOverrides({
    this.model,
    this.effort,
    this.summary,
    this.approvalPolicy,
    this.sandboxPolicy,
    this.cwd,
    this.personality,
    this.serviceTier,
  });

  static const empty = CodexConfigOverrides();

  final String? model;
  final String? effort;
  final String? summary;
  final Object? approvalPolicy;
  final Map<String, Object?>? sandboxPolicy;
  final String? cwd;
  final String? personality;
  final String? serviceTier;

  bool get isEmpty => toTurnStartParams().isEmpty;

  CodexConfigOverrides merge(CodexConfigOverrides higherPriority) {
    return CodexConfigOverrides(
      model: _stringOverride(model, higherPriority.model),
      effort: _stringOverride(effort, higherPriority.effort),
      summary: _stringOverride(summary, higherPriority.summary),
      approvalPolicy: _objectOverride(
        approvalPolicy,
        higherPriority.approvalPolicy,
      ),
      sandboxPolicy: _mapOverride(sandboxPolicy, higherPriority.sandboxPolicy),
      cwd: _stringOverride(cwd, higherPriority.cwd),
      personality: _stringOverride(personality, higherPriority.personality),
      serviceTier: _stringOverride(serviceTier, higherPriority.serviceTier),
    );
  }

  Map<String, Object?> toTurnStartParams() {
    return {
      if (_hasText(model)) 'model': model,
      if (_hasText(effort)) 'effort': effort,
      if (_hasText(summary)) 'summary': summary,
      if (_hasObjectOverride(approvalPolicy)) 'approvalPolicy': approvalPolicy,
      if (_hasMap(sandboxPolicy)) 'sandboxPolicy': sandboxPolicy,
      if (_hasText(cwd)) 'cwd': cwd,
      if (_hasText(personality)) 'personality': personality,
      if (_hasText(serviceTier)) 'serviceTier': serviceTier,
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
    if (turn.toTurnStartParams().containsKey(fieldName)) {
      return CodexConfigOverrideSource.turn;
    }
    if (session.toTurnStartParams().containsKey(fieldName)) {
      return CodexConfigOverrideSource.session;
    }
    if (appDefault.toTurnStartParams().containsKey(fieldName)) {
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
