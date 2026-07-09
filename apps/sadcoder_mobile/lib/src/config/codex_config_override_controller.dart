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
      cwd: overrides.cwd,
      personality: overrides.personality,
      serviceTier: overrides.serviceTier,
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
      cwd: overrides.cwd,
      personality: personality,
      serviceTier: overrides.serviceTier,
    );
  }
}
