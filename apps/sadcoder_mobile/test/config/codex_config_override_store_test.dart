import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_store.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('SharedPreferences store persists app default overrides', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesCodexConfigOverrideStore();
    const overrides = CodexConfigOverrides(
      model: 'gpt-5-codex',
      effort: 'high',
      summary: 'auto',
      approvalPolicy: 'on-request',
      sandboxPolicy: {'mode': 'workspace-write'},
      cwd: '/repo',
      personality: 'pragmatic',
      serviceTier: 'priority',
    );

    await store.saveAppDefaults(overrides);
    final loaded = await store.loadAppDefaults();

    expect(loaded.toTurnStartParams(), {
      'model': 'gpt-5-codex',
      'effort': 'high',
      'summary': 'auto',
      'approvalPolicy': 'on-request',
      'sandboxPolicy': {'mode': 'workspace-write'},
      'cwd': '/repo',
      'personality': 'pragmatic',
      'serviceTier': 'priority',
    });
  });

  test('SharedPreferences store persists permission profiles', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesCodexConfigOverrideStore();
    const overrides = CodexConfigOverrides(
      permissionProfile: 'trusted-workspace',
      sandboxPolicy: {'mode': 'read-only'},
    );

    await store.saveAppDefaults(overrides);
    final loaded = await store.loadAppDefaults();

    expect(loaded.permissionProfile, 'trusted-workspace');
    expect(loaded.sandboxPolicy, isNull);
    expect(loaded.toTurnStartParams(), {'permissions': 'trusted-workspace'});
  });

  test(
    'SharedPreferences store preserves explicit model and effort with collaboration mode',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesCodexConfigOverrideStore();
      const overrides = CodexConfigOverrides(
        model: 'gpt-5.6-sol',
        effort: 'high',
        collaborationMode: CodexCollaborationModeOverride(
          mode: 'plan',
          model: 'gpt-5.6-terra',
          reasoningEffort: 'medium',
          developerInstructions: 'Plan first.',
        ),
      );

      await store.saveAppDefaults(overrides);
      final loaded = await store.loadAppDefaults();

      expect(loaded.model, 'gpt-5.6-sol');
      expect(loaded.effort, 'high');
      expect(loaded.collaborationMode?.toJson(), {
        'mode': 'plan',
        'settings': {
          'model': 'gpt-5.6-terra',
          'reasoning_effort': 'medium',
          'developer_instructions': 'Plan first.',
        },
      });
      expect(loaded.toTurnStartParams(), {
        'collaborationMode': {
          'mode': 'plan',
          'settings': {
            'model': 'gpt-5.6-terra',
            'reasoning_effort': 'medium',
            'developer_instructions': 'Plan first.',
          },
        },
      });
    },
  );

  test('SharedPreferences store reads legacy permissions key', () async {
    SharedPreferences.setMockInitialValues({
      'codex.config.appDefaults.v1': '{"permissions":"trusted-workspace"}',
    });
    const store = SharedPreferencesCodexConfigOverrideStore();

    final loaded = await store.loadAppDefaults();

    expect(loaded.permissionProfile, 'trusted-workspace');
  });

  test(
    'SharedPreferences store falls back to empty overrides for invalid data',
    () async {
      SharedPreferences.setMockInitialValues({
        'codex.config.appDefaults.v1': '{not json',
      });
      const store = SharedPreferencesCodexConfigOverrideStore();

      final loaded = await store.loadAppDefaults();

      expect(loaded.toTurnStartParams(), isEmpty);
    },
  );

  test('persisted controller saves only app default layer changes', () async {
    final store = _FakeCodexConfigOverrideStore(
      const CodexConfigOverrides(model: 'gpt-5'),
    );

    final controller = await PersistedCodexConfigOverrideController.load(
      store: store,
    );
    addTearDown(controller.dispose);

    expect(controller.layers.appDefault.model, 'gpt-5');

    controller.setSession(const CodexConfigOverrides(model: 'gpt-5-codex'));
    controller.setTurn(const CodexConfigOverrides(effort: 'high'));
    controller.setAppDefault(const CodexConfigOverrides(model: 'gpt-5.6'));
    controller.setAppDefault(const CodexConfigOverrides(model: 'gpt-5.6'));

    expect(store.saved, hasLength(1));
    expect(store.saved.single.toTurnStartParams(), {'model': 'gpt-5.6'});
  });

  test(
    'persisted controller saves explicit fields hidden by wire params',
    () async {
      final store = _FakeCodexConfigOverrideStore(
        const CodexConfigOverrides(
          model: 'gpt-5.6-sol',
          collaborationMode: CodexCollaborationModeOverride(
            mode: 'plan',
            model: 'gpt-5.6-terra',
            reasoningEffort: 'medium',
          ),
        ),
      );

      final controller = await PersistedCodexConfigOverrideController.load(
        store: store,
      );
      addTearDown(controller.dispose);

      controller.setAppDefault(
        const CodexConfigOverrides(
          model: 'gpt-5.6-luna',
          collaborationMode: CodexCollaborationModeOverride(
            mode: 'plan',
            model: 'gpt-5.6-terra',
            reasoningEffort: 'medium',
          ),
        ),
      );

      expect(store.saved, hasLength(1));
      expect(store.saved.single.model, 'gpt-5.6-luna');
    },
  );
}

class _FakeCodexConfigOverrideStore implements CodexConfigOverrideStore {
  _FakeCodexConfigOverrideStore(this.appDefault);

  CodexConfigOverrides appDefault;
  final saved = <CodexConfigOverrides>[];

  @override
  Future<CodexConfigOverrides> loadAppDefaults() async => appDefault;

  @override
  Future<void> saveAppDefaults(CodexConfigOverrides overrides) async {
    appDefault = overrides;
    saved.add(overrides);
  }
}
