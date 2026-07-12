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

  test('clearTurn clears only the turn override layer', () {
    final controller = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5'),
        session: CodexConfigOverrides(cwd: '/repo'),
        turn: CodexConfigOverrides(effort: 'high', personality: 'concise'),
      ),
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    controller.clearTurn();

    expect(notifications, 1);
    expect(controller.layers.appDefault.toTurnStartParams(), {
      'model': 'gpt-5',
    });
    expect(controller.layers.session.toTurnStartParams(), {'cwd': '/repo'});
    expect(controller.layers.turn.toTurnStartParams(), isEmpty);
    expect(controller.resolved.toTurnStartParams(), {
      'model': 'gpt-5',
      'cwd': '/repo',
    });
  });

  test('restoreServerDefaults clears every override layer', () {
    final controller = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5'),
        session: CodexConfigOverrides(cwd: '/repo'),
        turn: CodexConfigOverrides(effort: 'high'),
      ),
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    controller.restoreServerDefaults();

    expect(notifications, 1);
    expect(controller.layers.appDefault.toTurnStartParams(), isEmpty);
    expect(controller.layers.session.toTurnStartParams(), isEmpty);
    expect(controller.layers.turn.toTurnStartParams(), isEmpty);
    expect(controller.resolved.toTurnStartParams(), isEmpty);
    expect(
      controller.sourceFor('model'),
      CodexConfigOverrideSource.serverDefault,
    );
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

  test('permission helpers preserve unrelated override fields', () {
    final controller = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(model: 'gpt-5', personality: 'concise'),
        turn: CodexConfigOverrides(cwd: '/tmp', effort: 'high'),
      ),
    );
    addTearDown(controller.dispose);

    controller.setSessionPermissions(
      approvalPolicy: 'on-request',
      sandboxPolicy: {'type': 'readOnly', 'networkAccess': false},
    );
    controller.setTurnPermissions(
      approvalPolicy: '',
      sandboxPolicy: {'type': 'dangerFullAccess', 'networkAccess': true},
      permissionProfile: ':danger-full-access',
    );

    expect(controller.layers.session.toTurnStartParams(), {
      'model': 'gpt-5',
      'approvalPolicy': 'on-request',
      'sandboxPolicy': {'type': 'readOnly', 'networkAccess': false},
      'personality': 'concise',
    });
    expect(controller.layers.turn.toTurnStartParams(), {
      'permissions': ':danger-full-access',
      'cwd': '/tmp',
      'effort': 'high',
    });
  });

  test('collaboration mode helpers preserve unrelated override fields', () {
    final controller = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(cwd: '/repo', personality: 'concise'),
        turn: CodexConfigOverrides(approvalPolicy: 'on-request'),
      ),
    );
    addTearDown(controller.dispose);

    controller.setSessionCollaborationMode(
      CodexCollaborationModeOverride.plan(model: 'gpt-5-codex'),
    );
    controller.setTurnCollaborationMode(
      CodexCollaborationModeOverride.plan(model: 'gpt-5'),
    );

    expect(controller.layers.session.toTurnStartParams(), {
      'cwd': '/repo',
      'personality': 'concise',
      'collaborationMode': {
        'mode': 'plan',
        'settings': {
          'model': 'gpt-5-codex',
          'reasoning_effort': 'medium',
          'developer_instructions': null,
        },
      },
    });
    expect(controller.layers.turn.toTurnStartParams(), {
      'approvalPolicy': 'on-request',
      'collaborationMode': {
        'mode': 'plan',
        'settings': {
          'model': 'gpt-5',
          'reasoning_effort': 'medium',
          'developer_instructions': null,
        },
      },
    });
  });
}
