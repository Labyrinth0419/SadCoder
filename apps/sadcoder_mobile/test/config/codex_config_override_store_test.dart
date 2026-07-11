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
