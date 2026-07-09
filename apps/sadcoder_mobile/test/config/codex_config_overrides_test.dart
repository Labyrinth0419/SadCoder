import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';

void main() {
  test('empty overrides serialize no turn start params', () {
    expect(CodexConfigOverrides.empty.toTurnStartParams(), isEmpty);
    expect(CodexConfigOverrides.empty.isEmpty, true);
  });

  test('resolves app session and turn layers by priority', () {
    final layers = CodexConfigOverrideLayers(
      appDefault: const CodexConfigOverrides(
        model: 'gpt-5',
        effort: 'medium',
        approvalPolicy: 'on-request',
      ),
      session: const CodexConfigOverrides(model: 'gpt-5-codex'),
      turn: const CodexConfigOverrides(
        effort: 'high',
        cwd: '/repo',
        sandboxPolicy: {'type': 'readOnly', 'networkAccess': false},
      ),
    );

    expect(layers.resolve().toTurnStartParams(), {
      'model': 'gpt-5-codex',
      'effort': 'high',
      'approvalPolicy': 'on-request',
      'cwd': '/repo',
      'sandboxPolicy': {'type': 'readOnly', 'networkAccess': false},
    });
    expect(layers.sourceFor('model'), CodexConfigOverrideSource.session);
    expect(layers.sourceFor('effort'), CodexConfigOverrideSource.turn);
    expect(
      layers.sourceFor('summary'),
      CodexConfigOverrideSource.serverDefault,
    );
  });

  test('blank strings do not override server defaults', () {
    final layers = CodexConfigOverrideLayers(
      appDefault: const CodexConfigOverrides(
        model: 'gpt-5',
        approvalPolicy: 'on-request',
        sandboxPolicy: {'type': 'readOnly'},
      ),
      session: const CodexConfigOverrides(
        model: '   ',
        approvalPolicy: ' ',
        sandboxPolicy: {},
      ),
    );

    expect(layers.resolve().toTurnStartParams(), {
      'model': 'gpt-5',
      'approvalPolicy': 'on-request',
      'sandboxPolicy': {'type': 'readOnly'},
    });
    expect(layers.sourceFor('model'), CodexConfigOverrideSource.appDefault);
    expect(
      layers.sourceFor('approvalPolicy'),
      CodexConfigOverrideSource.appDefault,
    );
    expect(
      layers.sourceFor('sandboxPolicy'),
      CodexConfigOverrideSource.appDefault,
    );
  });
}
