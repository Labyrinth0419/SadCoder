import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';

void main() {
  test('parses config read responses and preserves raw JSON', () {
    final snapshot = CodexConfigSnapshot.fromJson({
      'config': {
        'model': 'gpt-5-codex',
        'model_reasoning_effort': 'high',
        'approval_policy': {'type': 'on-request'},
        'sandbox_mode': {'type': 'workspace-write'},
      },
      'origins': {
        'model': {
          'name': {'type': 'user', 'file': '/home/me/.codex/config.toml'},
          'version': 'v1',
        },
        'model_reasoning_effort': {
          'name': {'type': 'project', 'dot_codex_folder': '/repo/.codex'},
          'version': 'v2',
        },
      },
      'layers': [
        {
          'name': {
            'type': 'user',
            'file': '/home/me/.codex/config.toml',
            'profile': null,
          },
          'version': 'v1',
          'config': {'model': 'gpt-5-codex'},
        },
      ],
    });

    expect(snapshot.displayValueFor('model'), 'gpt-5-codex');
    expect(snapshot.displayValueFor('approval_policy'), 'on-request');
    expect(snapshot.displayValueFor('sandbox_mode'), 'workspace-write');
    expect(
      snapshot.originLabelFor('model'),
      'user: /home/me/.codex/config.toml',
    );
    expect(
      snapshot.originLabelFor('model_reasoning_effort'),
      'project: /repo/.codex',
    );
    expect(snapshot.layers.single['version'], 'v1');
    expect(snapshot.userConfigVersion, 'v1');
    expect(
      snapshot.toRawJson()['config'],
      containsPair('model', 'gpt-5-codex'),
    );
  });

  test('treats missing and null values as unset display values', () {
    final snapshot = CodexConfigSnapshot.fromJson({
      'config': {'model': null, 'service_tier': ''},
    });

    expect(snapshot.displayValueFor('model'), isNull);
    expect(snapshot.displayValueFor('service_tier'), isNull);
    expect(snapshot.originLabelFor('model'), isNull);
  });

  test('preserves managed requirements and support state', () {
    final snapshot = CodexConfigSnapshot.fromJson({
      'config': const <String, Object?>{},
      'requirementsSupported': true,
      'requirements': {
        'allowedSandboxModes': ['workspace-write'],
        'featureRequirements': {'remote_control': false},
      },
    });

    expect(snapshot.requirementsSupported, isTrue);
    expect(snapshot.requirements?['allowedSandboxModes'], ['workspace-write']);
    expect(snapshot.toRawJson(), containsPair('requirementsSupported', true));
  });
}
