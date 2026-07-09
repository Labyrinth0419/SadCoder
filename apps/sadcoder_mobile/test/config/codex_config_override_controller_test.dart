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

  test('model effort helpers preserve unrelated override fields', () {
    final controller = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(cwd: '/repo', personality: 'pragmatic'),
        turn: CodexConfigOverrides(cwd: '/tmp', approvalPolicy: 'on-request'),
      ),
    );
    addTearDown(controller.dispose);

    controller.setSessionModelEffort(model: 'gpt-5-codex', effort: 'high');
    controller.setTurnModelEffort(model: 'gpt-5', effort: '');

    expect(controller.layers.session.toTurnStartParams(), {
      'model': 'gpt-5-codex',
      'effort': 'high',
      'cwd': '/repo',
      'personality': 'pragmatic',
    });
    expect(controller.layers.turn.toTurnStartParams(), {
      'model': 'gpt-5',
      'approvalPolicy': 'on-request',
      'cwd': '/tmp',
    });
  });

  test('personality helpers preserve unrelated override fields', () {
    final controller = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(model: 'gpt-5', cwd: '/repo'),
        turn: CodexConfigOverrides(effort: 'high', serviceTier: 'auto'),
      ),
    );
    addTearDown(controller.dispose);

    controller.setSessionPersonality('concise');
    controller.setTurnPersonality('pragmatic');

    expect(controller.layers.session.toTurnStartParams(), {
      'model': 'gpt-5',
      'cwd': '/repo',
      'personality': 'concise',
    });
    expect(controller.layers.turn.toTurnStartParams(), {
      'effort': 'high',
      'personality': 'pragmatic',
      'serviceTier': 'auto',
    });
  });
}
