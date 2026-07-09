import 'package:flutter/foundation.dart';

import 'codex_config_overrides.dart';

class CodexConfigOverrideController extends ChangeNotifier {
  CodexConfigOverrideController({
    CodexConfigOverrideLayers initialLayers = const CodexConfigOverrideLayers(),
  }) : _layers = initialLayers;

  CodexConfigOverrideLayers _layers;

  CodexConfigOverrideLayers get layers => _layers;

  CodexConfigOverrides get resolved => _layers.resolve();

  void setAppDefault(CodexConfigOverrides overrides) {
    _setLayers(
      CodexConfigOverrideLayers(
        appDefault: overrides,
        session: _layers.session,
        turn: _layers.turn,
      ),
    );
  }

  void setSession(CodexConfigOverrides overrides) {
    _setLayers(
      CodexConfigOverrideLayers(
        appDefault: _layers.appDefault,
        session: overrides,
        turn: _layers.turn,
      ),
    );
  }

  void setTurn(CodexConfigOverrides overrides) {
    _setLayers(
      CodexConfigOverrideLayers(
        appDefault: _layers.appDefault,
        session: _layers.session,
        turn: overrides,
      ),
    );
  }

  void setSessionModelEffort({required String model, required String effort}) {
    setSession(_withModelEffort(_layers.session, model: model, effort: effort));
  }

  void setTurnModelEffort({required String model, required String effort}) {
    setTurn(_withModelEffort(_layers.turn, model: model, effort: effort));
  }

  void setSessionPersonality(String personality) {
    setSession(_withPersonality(_layers.session, personality: personality));
  }

  void setTurnPersonality(String personality) {
    setTurn(_withPersonality(_layers.turn, personality: personality));
  }

  void setSessionCollaborationMode(
    CodexCollaborationModeOverride collaborationMode,
  ) {
    setSession(
      _withCollaborationMode(
        _layers.session,
        collaborationMode: collaborationMode,
      ),
    );
  }

  void setTurnCollaborationMode(
    CodexCollaborationModeOverride collaborationMode,
  ) {
    setTurn(
      _withCollaborationMode(
        _layers.turn,
        collaborationMode: collaborationMode,
      ),
    );
  }

  void setSessionPermissions({
    required Object? approvalPolicy,
    required Map<String, Object?> sandboxPolicy,
    String? permissionProfile,
  }) {
    setSession(
      _withPermissions(
        _layers.session,
        approvalPolicy: approvalPolicy,
        sandboxPolicy: sandboxPolicy,
        permissionProfile: permissionProfile,
      ),
    );
  }

  void setTurnPermissions({
    required Object? approvalPolicy,
    required Map<String, Object?> sandboxPolicy,
    String? permissionProfile,
  }) {
    setTurn(
      _withPermissions(
        _layers.turn,
        approvalPolicy: approvalPolicy,
        sandboxPolicy: sandboxPolicy,
        permissionProfile: permissionProfile,
      ),
    );
  }

  void clearTurn() {
    setTurn(CodexConfigOverrides.empty);
  }

  void clearSession() {
    setSession(CodexConfigOverrides.empty);
  }

  CodexConfigOverrideSource sourceFor(String fieldName) {
    return _layers.sourceFor(fieldName);
  }

  void _setLayers(CodexConfigOverrideLayers layers) {
    _layers = layers;
    notifyListeners();
  }

  CodexConfigOverrides _withModelEffort(
    CodexConfigOverrides overrides, {
    required String model,
    required String effort,
  }) {
    return CodexConfigOverrides(
      model: model,
      effort: effort,
      summary: overrides.summary,
      approvalPolicy: overrides.approvalPolicy,
      sandboxPolicy: overrides.sandboxPolicy,
      permissionProfile: overrides.permissionProfile,
      cwd: overrides.cwd,
      personality: overrides.personality,
      serviceTier: overrides.serviceTier,
      collaborationMode: overrides.collaborationMode,
    );
  }

  CodexConfigOverrides _withPersonality(
    CodexConfigOverrides overrides, {
    required String personality,
  }) {
    return CodexConfigOverrides(
      model: overrides.model,
      effort: overrides.effort,
      summary: overrides.summary,
      approvalPolicy: overrides.approvalPolicy,
      sandboxPolicy: overrides.sandboxPolicy,
      permissionProfile: overrides.permissionProfile,
      cwd: overrides.cwd,
      personality: personality,
      serviceTier: overrides.serviceTier,
      collaborationMode: overrides.collaborationMode,
    );
  }

  CodexConfigOverrides _withCollaborationMode(
    CodexConfigOverrides overrides, {
    required CodexCollaborationModeOverride collaborationMode,
  }) {
    return CodexConfigOverrides(
      model: overrides.model,
      effort: overrides.effort,
      summary: overrides.summary,
      approvalPolicy: overrides.approvalPolicy,
      sandboxPolicy: overrides.sandboxPolicy,
      permissionProfile: overrides.permissionProfile,
      cwd: overrides.cwd,
      personality: overrides.personality,
      serviceTier: overrides.serviceTier,
      collaborationMode: collaborationMode,
    );
  }

  CodexConfigOverrides _withPermissions(
    CodexConfigOverrides overrides, {
    required Object? approvalPolicy,
    required Map<String, Object?> sandboxPolicy,
    String? permissionProfile,
  }) {
    final normalizedPermissionProfile = _normalizeText(permissionProfile);
    return CodexConfigOverrides(
      model: overrides.model,
      effort: overrides.effort,
      summary: overrides.summary,
      approvalPolicy: approvalPolicy,
      sandboxPolicy: normalizedPermissionProfile == null ? sandboxPolicy : null,
      permissionProfile: normalizedPermissionProfile,
      cwd: overrides.cwd,
      personality: overrides.personality,
      serviceTier: overrides.serviceTier,
      collaborationMode: overrides.collaborationMode,
    );
  }
}

String? _normalizeText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}
