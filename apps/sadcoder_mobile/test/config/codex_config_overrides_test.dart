import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';

void main() {
  test('empty overrides serialize no turn start params', () {
    expect(CodexConfigOverrides.empty.toTurnStartParams(), isEmpty);
    expect(CodexConfigOverrides.empty.toThreadSettingsUpdateParams(), isEmpty);
    expect(CodexConfigOverrides.empty.isEmpty, true);
  });

  test('resolves app session and turn layers by priority', () {
    final layers = CodexConfigOverrideLayers(
      appDefault: const CodexConfigOverrides(
        model: 'gpt-5',
        effort: 'medium',
        approvalPolicy: 'on-request',
        permissionProfile: ':workspace',
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
      layers.sourceFor('permissionProfile'),
      CodexConfigOverrideSource.serverDefault,
    );
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

  test('permission profiles and sandbox policies are mutually exclusive', () {
    final profileWins = const CodexConfigOverrideLayers(
      appDefault: CodexConfigOverrides(sandboxPolicy: {'type': 'readOnly'}),
      session: CodexConfigOverrides(permissionProfile: ':workspace'),
    );
    final sandboxWins = const CodexConfigOverrideLayers(
      appDefault: CodexConfigOverrides(permissionProfile: ':workspace'),
      session: CodexConfigOverrides(sandboxPolicy: {'type': 'readOnly'}),
    );

    expect(profileWins.resolve().toTurnStartParams(), {
      'permissions': ':workspace',
    });
    expect(sandboxWins.resolve().toTurnStartParams(), {
      'sandboxPolicy': {'type': 'readOnly'},
    });
    expect(
      profileWins.sourceFor('permissionProfile'),
      CodexConfigOverrideSource.session,
    );
    expect(
      sandboxWins.sourceFor('permissionProfile'),
      CodexConfigOverrideSource.serverDefault,
    );
  });

  test('collaboration mode serializes as turn start params', () {
    final layers = CodexConfigOverrideLayers(
      appDefault: const CodexConfigOverrides(model: 'gpt-5'),
      turn: CodexConfigOverrides(
        collaborationMode: CodexCollaborationModeOverride.plan(
          model: 'gpt-5-codex',
        ),
      ),
    );

    expect(layers.resolve().toTurnStartParams(), {
      'collaborationMode': {
        'mode': 'plan',
        'settings': {
          'model': 'gpt-5-codex',
          'reasoning_effort': 'medium',
          'developer_instructions': null,
        },
      },
    });
    expect(
      layers.sourceFor('collaborationMode'),
      CodexConfigOverrideSource.turn,
    );
  });

  test('thread settings update params reuse explicit override fields', () {
    const overrides = CodexConfigOverrides(
      model: 'gpt-5-codex',
      effort: 'high',
      summary: 'detailed',
      approvalPolicy: 'on-request',
      permissionProfile: ':workspace',
      cwd: '/repo',
      personality: 'pragmatic',
      serviceTier: 'flex',
      sandboxPolicy: {'type': 'readOnly'},
    );

    expect(overrides.toThreadSettingsUpdateParams(), {
      'model': 'gpt-5-codex',
      'effort': 'high',
      'summary': 'detailed',
      'approvalPolicy': 'on-request',
      'permissions': ':workspace',
      'cwd': '/repo',
      'personality': 'pragmatic',
      'serviceTier': 'flex',
    });
  });
}
