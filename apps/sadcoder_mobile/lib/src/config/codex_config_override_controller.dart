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

  void clearTurn() {
    setTurn(CodexConfigOverrides.empty);
  }

  CodexConfigOverrideSource sourceFor(String fieldName) {
    return _layers.sourceFor(fieldName);
  }

  void _setLayers(CodexConfigOverrideLayers layers) {
    _layers = layers;
    notifyListeners();
  }
}
