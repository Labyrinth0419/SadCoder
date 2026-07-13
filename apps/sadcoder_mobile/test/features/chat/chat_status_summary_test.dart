import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_status_summary.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_controller.dart';
import 'package:sadcoder_mobile/src/turns/turn_controller.dart';
import 'package:sadcoder_mobile/src/usage/thread_token_usage_controller.dart';

void main() {
  test('buildChatStatusSummary reports disconnected config sources', () {
    final l10n = AppLocalizations(const Locale('en'));
    final overrides = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5'),
        session: CodexConfigOverrides(cwd: '/repo'),
      ),
    );
    addTearDown(overrides.dispose);

    expect(
      buildChatStatusSummary(l10n: l10n, configOverrideController: overrides),
      'Connection status: Disconnected\n'
      'Model: gpt-5 / app default\n'
      'Reasoning effort: server default\n'
      'Collaboration mode: server default\n'
      'Approval policy: server default\n'
      'Permission profile: server default\n'
      'Sandbox mode: server default\n'
      'Working directory: /repo / session override\n'
      'Personality: server default',
    );
  });

  test('buildChatStatusSummary reports account status', () async {
    final l10n = AppLocalizations(const Locale('en'));
    final accountController = AccountSnapshotController(
      readerProvider: () => _FakeAccountSnapshotReader(
        snapshot: const AccountSnapshot(
          account: AccountSummary(
            type: 'chatgpt',
            email: 'user@example.com',
            planType: 'plus',
          ),
          requiresOpenaiAuth: true,
        ),
      ),
    );
    addTearDown(accountController.dispose);

    await accountController.refresh();

    expect(
      buildChatStatusSummary(
        l10n: l10n,
        accountSnapshotController: accountController,
      ),
      'Connection status: Disconnected\n'
      'Account: ChatGPT / user@example.com / plus / OpenAI auth required',
    );
  });

  test('buildChatStatusSummary flags high-risk permission states', () async {
    final l10n = AppLocalizations(const Locale('en'));
    final overrides = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(
          approvalPolicy: 'never',
          sandboxPolicy: {'type': 'dangerFullAccess'},
        ),
      ),
    );
    final snapshotController = CodexConfigSnapshotController(
      readerProvider: () => _FakeConfigSnapshotReader(
        snapshot: CodexConfigSnapshot.fromJson({
          'config': {
            'approval_policy': {'type': 'on-request'},
            'default_permissions': ':danger-full-access',
            'sandbox_mode': {'type': 'workspace-write'},
          },
        }),
      ),
    );
    addTearDown(overrides.dispose);
    addTearDown(snapshotController.dispose);

    await snapshotController.refresh();

    final summary = buildChatStatusSummary(
      l10n: l10n,
      configOverrideController: overrides,
      configSnapshotController: snapshotController,
    );

    expect(
      RegExp(
        RegExp.escape(
          'High risk: these permissions can let Codex run with less review or broader filesystem access.',
        ),
      ).allMatches(summary),
      hasLength(2),
    );
  });

  test('buildChatStatusSummary does not show usage for another thread', () {
    final l10n = AppLocalizations(const Locale('en'));
    final threadDetailController = ThreadDetailController(
      readerProvider: () => null,
    )..restoreCachedSelection('thr_selected');
    final threadTokenUsageController = ThreadTokenUsageController()
      ..ingestTokenUsageUpdated({
        'threadId': 'thr_other',
        'turnId': 'turn_1',
        'tokenUsage': {
          'last': {
            'cachedInputTokens': 0,
            'inputTokens': 10,
            'outputTokens': 5,
            'reasoningOutputTokens': 1,
            'totalTokens': 16,
          },
          'total': {
            'cachedInputTokens': 0,
            'inputTokens': 100,
            'outputTokens': 50,
            'reasoningOutputTokens': 10,
            'totalTokens': 160,
          },
        },
      });
    addTearDown(threadTokenUsageController.dispose);
    addTearDown(threadDetailController.dispose);

    final summary = buildChatStatusSummary(
      l10n: l10n,
      threadDetailController: threadDetailController,
      threadTokenUsageController: threadTokenUsageController,
    );

    expect(summary, contains('Thread: thr_selected'));
    expect(summary, isNot(contains('Thread tokens')));
    expect(summary, isNot(contains('160 tokens')));
  });

  test('buildChatStatusSummary localizes failure details', () async {
    const zh = AppLocalizations(Locale('zh', 'CN'));
    final configController = CodexConfigSnapshotController(
      readerProvider: () => _FailingConfigSnapshotReader(),
    );
    final accountController = AccountSnapshotController(
      readerProvider: () => _FailingAccountSnapshotReader(),
    );
    addTearDown(configController.dispose);
    addTearDown(accountController.dispose);

    await configController.refresh();
    await accountController.refresh();

    final summary = buildChatStatusSummary(
      l10n: zh,
      configSnapshotController: configController,
      accountSnapshotController: accountController,
    );

    expect(summary, contains('服务器配置快照: 服务器配置加载失败：Bad state: config failed'));
    expect(summary, contains('账户: 账户加载失败：Bad state: account failed'));
  });

  test(
    'buildChatStatusSummary localizes app-generated turn failures',
    () async {
      const zh = AppLocalizations(Locale('zh', 'CN'));
      final turnController = TurnController(runnerProvider: () => null);
      addTearDown(turnController.dispose);

      await turnController.submitText('修复问题');

      final summary = buildChatStatusSummary(
        l10n: zh,
        turnController: turnController,
      );

      expect(summary, contains('回合: 没有可用的 Codex 会话。'));
      expect(summary, isNot(contains('No active Codex session')));
      expect(summary, isNot(contains('Bad state')));
    },
  );
}

class _FakeAccountSnapshotReader implements AccountSnapshotReader {
  const _FakeAccountSnapshotReader({required this.snapshot});

  final AccountSnapshot snapshot;

  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) async {
    return snapshot;
  }
}

class _FakeConfigSnapshotReader implements CodexConfigSnapshotReader {
  const _FakeConfigSnapshotReader({required this.snapshot});

  final CodexConfigSnapshot snapshot;

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    return snapshot;
  }
}

class _FailingConfigSnapshotReader implements CodexConfigSnapshotReader {
  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    throw StateError('config failed');
  }
}

class _FailingAccountSnapshotReader implements AccountSnapshotReader {
  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) async {
    throw StateError('account failed');
  }
}
