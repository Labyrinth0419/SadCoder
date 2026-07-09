import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';

void main() {
  test('clearSession clears only the session override layer', () {
    final controller = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5'),
        session: CodexConfigOverrides(model: 'gpt-5-codex', cwd: '/repo'),
        turn: CodexConfigOverrides(effort: 'high'),
      ),
    );
    addTearDown(controller.dispose);

    controller.clearSession();

    expect(controller.layers.appDefault.toTurnStartParams(), {
      'model': 'gpt-5',
    });
    expect(controller.layers.session.toTurnStartParams(), isEmpty);
    expect(controller.layers.turn.toTurnStartParams(), {'effort': 'high'});
    expect(controller.resolved.toTurnStartParams(), {
      'model': 'gpt-5',
      'effort': 'high',
    });
  });
}
