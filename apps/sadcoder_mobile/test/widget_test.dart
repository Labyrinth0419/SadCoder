import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_logout_runner.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/approvals/approval_request_mapper.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/approvals/pending_approval.dart';
import 'package:sadcoder_mobile/src/apps/app_list_reader.dart';
import 'package:sadcoder_mobile/src/app/sadcoder_app.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal_runner.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/diffs/git_diff_reader.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/feedback/feedback_upload_runner.dart';
import 'package:sadcoder_mobile/src/files/file_search_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_directory_reader.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_kind.dart';
import 'package:sadcoder_mobile/src/files/workspace_file_reader.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal.dart';
import 'package:sadcoder_mobile/src/goals/thread_goal_runner.dart';
import 'package:sadcoder_mobile/src/hooks/hook_list_reader.dart';
import 'package:sadcoder_mobile/src/mcp/mcp_server_status_reader.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_reader.dart';
import 'package:sadcoder_mobile/src/plugins/plugin_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc_diagnostic_log.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review_runner.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/skills/skill_list_reader.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';
import 'package:sadcoder_mobile/src/threads/thread_detail_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/thread_mutation_runner.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';
import 'package:sadcoder_mobile/src/turns/turn_runner.dart';
import 'package:sadcoder_mobile/src/turns/turn_text_element.dart';
import 'package:sadcoder_mobile/src/usage/account_usage_snapshot_reader.dart';

void main() {
  testWidgets('renders the SadCoder shell', (tester) async {
    await tester.pumpWidget(const SadCoderApp());

    expect(find.text('Hosts'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Files'), findsWidgets);
    expect(find.text('Approvals'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('SSH profile'), findsOneWidget);
  });

  testWidgets('renders Chinese localization', (tester) async {
    await tester.pumpWidget(const SadCoderApp(locale: Locale('zh')));

    expect(find.text('主机'), findsWidgets);
    expect(find.text('SSH 配置'), findsOneWidget);
    expect(find.text('对话'), findsWidgets);
    expect(find.text('文件'), findsWidgets);
    expect(find.text('审批'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('applies injected appearance theme mode', (tester) async {
    final appearanceController = AppAppearanceController(
      theme: AppThemePreference.dark,
    );
    addTearDown(appearanceController.dispose);

    await tester.pumpWidget(
      SadCoderApp(appearanceController: appearanceController),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.theme?.extension<SadCoderThemeColors>(),
      SadCoderThemeColors.light,
    );
    expect(
      app.darkTheme?.extension<SadCoderThemeColors>(),
      SadCoderThemeColors.dark,
    );
    expect(app.themeMode, ThemeMode.dark);

    appearanceController.setTheme(AppThemePreference.light);
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    appearanceController.setTheme(AppThemePreference.system);
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
  });

  testWidgets('renders injected pending approvals in the shell', (
    tester,
  ) async {
    final approvalController = ApprovalStateController(
      initialApprovals: const [
        PendingApproval(
          requestId: 'approval-1',
          method: commandExecutionApprovalMethod,
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
          title: 'cargo test',
          command: 'cargo test',
        ),
      ],
    );
    addTearDown(approvalController.dispose);

    await tester.pumpWidget(
      SadCoderApp(approvalController: approvalController),
    );
    await tester.tap(find.text('Approvals').last);
    await tester.pumpAndSettle();

    expect(find.text('cargo test'), findsWidgets);
    expect(find.text('Command approval'), findsOneWidget);
  });

  testWidgets('uses the injected session approval controller in the shell', (
    tester,
  ) async {
    final approvalController = ApprovalStateController(
      initialApprovals: const [
        PendingApproval(
          requestId: 'approval-1',
          method: commandExecutionApprovalMethod,
          kind: PendingApprovalKind.commandExecution,
          rawParams: {},
          title: 'cargo test',
          command: 'cargo test',
        ),
      ],
    );
    final sessionController = CodexSessionStateController(
      connector: _NeverConnectsSessionStarter(),
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await tester.pumpWidget(SadCoderApp(sessionController: sessionController));
    await tester.tap(find.text('Approvals').last);
    await tester.pumpAndSettle();

    expect(find.text('cargo test'), findsWidgets);
    expect(find.text('Command approval'), findsOneWidget);
  });

  testWidgets('backfills chat timeline from loaded thread detail', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final sessionController = CodexSessionStateController(
      connector: _StaticSessionStarter(
        threads: [
          ThreadSummary.fromJson({
            'id': 'thr_1',
            'sessionId': 'sess_1',
            'preview': 'Fix login bug',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
          }),
        ],
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_1',
            'sessionId': 'sess_1',
            'preview': 'Fix login bug',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'turns': [
              {
                'id': 'turn_1',
                'status': 'completed',
                'itemsView': 'full',
                'items': [
                  {
                    'id': 'item_1',
                    'type': 'agentMessage',
                    'text': 'History is visible',
                  },
                ],
              },
            ],
          }),
        ),
      ),
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await tester.pumpWidget(SadCoderApp(sessionController: sessionController));
    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle();
    final threadTile = find.byKey(const ValueKey('thread-summary-thr_1'));
    await tester.scrollUntilVisible(
      threadTile,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(threadTile);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Timeline'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Turn: turn_1 / completed'), findsOneWidget);
    expect(find.text('Item: agentMessage'), findsOneWidget);
    expect(find.text('History is visible'), findsOneWidget);
  });

  testWidgets('files page browses the selected thread cwd from the shell', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final directoryReader = _MapWorkspaceDirectoryReader({
      '': [
        const WorkspaceDirectoryEntry(
          root: '/repo',
          path: 'README.md',
          name: 'README.md',
          kind: WorkspaceFileKind.file,
          isHidden: false,
        ),
      ],
    });
    final fileReader = _MapWorkspaceFileReader(
      stats: const {
        'README.md': WorkspaceFileStat(
          root: '/repo',
          path: 'README.md',
          kind: WorkspaceFileKind.file,
          language: 'markdown',
        ),
      },
      chunks: const {
        'README.md': [
          WorkspaceFileReadChunk(
            root: '/repo',
            path: 'README.md',
            sizeBytes: 20,
            offset: 0,
            bytesRead: 20,
            hasMore: false,
            encoding: 'utf-8',
            isBinary: false,
            content: '# Shell file visible',
          ),
        ],
      },
    );
    final sessionController = CodexSessionStateController(
      connector: _StaticSessionStarter(
        threads: [
          ThreadSummary.fromJson({
            'id': 'thr_1',
            'sessionId': 'sess_1',
            'preview': 'Browse files',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
          }),
        ],
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_1',
            'sessionId': 'sess_1',
            'preview': 'Browse files',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
          }),
        ),
        workspaceDirectoryReader: directoryReader,
        workspaceFileReader: fileReader,
      ),
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await tester.pumpWidget(SadCoderApp(sessionController: sessionController));
    await tester.tap(find.text('Chat').last);
    await tester.pumpAndSettle();
    final threadTile = find.byKey(const ValueKey('thread-summary-thr_1'));
    await tester.scrollUntilVisible(
      threadTile,
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(threadTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();

    expect(find.text('Root: /repo'), findsOneWidget);
    expect(find.text('README.md'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('workspace-files-entry-README.md')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shell file visible'), findsOneWidget);
  });

  testWidgets('backgrounding without an active turn disconnects observation', (
    tester,
  ) async {
    final approvalController = ApprovalStateController();
    final sessionController = CodexSessionStateController(
      connector: _StaticSessionStarter(
        threads: [
          ThreadSummary.fromJson({
            'id': 'thr_1',
            'sessionId': 'sess_1',
            'preview': 'Idle thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
          }),
        ],
        detail: ThreadDetail(
          thread: ThreadSummary.fromJson({
            'id': 'thr_1',
            'sessionId': 'sess_1',
            'preview': 'Idle thread',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
          }),
        ),
      ),
      approvalController: approvalController,
    );
    addTearDown(sessionController.dispose);
    addTearDown(approvalController.dispose);

    await sessionController.connect(_profile);
    await tester.pumpWidget(SadCoderApp(sessionController: sessionController));
    await tester.pumpAndSettle();

    expect(sessionController.status, CodexSessionStatus.connected);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(sessionController.status, CodexSessionStatus.idle);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}

const _profile = SshProfile(
  id: 'local',
  name: 'Local',
  host: 'localhost',
  username: 'tester',
);

class _NeverConnectsSessionStarter implements CodexSessionConnectionStarter {
  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) {
    throw StateError('not used by this widget test');
  }
}

class _StaticSessionStarter implements CodexSessionConnectionStarter {
  const _StaticSessionStarter({
    required this.threads,
    required this.detail,
    this.workspaceDirectoryReader = const _NoopWorkspaceDirectoryReader(),
    this.workspaceFileReader = const _NoopWorkspaceFileReader(),
  });

  final List<ThreadSummary> threads;
  final ThreadDetail detail;
  final WorkspaceDirectoryReader workspaceDirectoryReader;
  final WorkspaceFileReader workspaceFileReader;

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    return _StaticSessionConnection(
      profile: profile,
      threads: threads,
      detail: detail,
      workspaceDirectoryReader: workspaceDirectoryReader,
      workspaceFileReader: workspaceFileReader,
    );
  }
}

class _StaticSessionConnection implements CodexSessionConnectionHandle {
  _StaticSessionConnection({
    required this.profile,
    required List<ThreadSummary> threads,
    required ThreadDetail detail,
    required this.workspaceDirectoryReader,
    required this.workspaceFileReader,
  }) : threadListReader = _StaticThreadListReader(threads),
       threadDetailReader = _StaticThreadDetailReader(detail),
       _doneCompleter = Completer<void>();

  final Completer<void> _doneCompleter;

  @override
  final SshProfile profile;

  @override
  final ThreadListReader threadListReader;

  @override
  final ThreadDetailReader threadDetailReader;

  @override
  CodexConfigSnapshotReader get configSnapshotReader =>
      const _StaticConfigSnapshotReader();

  @override
  AccountSnapshotReader get accountSnapshotReader =>
      const _StaticAccountSnapshotReader();

  @override
  AccountLogoutRunner get accountLogoutRunner =>
      const _NoopAccountLogoutRunner();

  @override
  AccountUsageSnapshotReader get accountUsageSnapshotReader =>
      const _StaticAccountUsageSnapshotReader();

  @override
  FeedbackUploadRunner get feedbackUploadRunner =>
      const _NoopFeedbackUploadRunner();

  @override
  GitDiffReader get gitDiffReader => const _NoopGitDiffReader();

  @override
  FileSearchReader get fileSearchReader => const _NoopFileSearchReader();

  @override
  final WorkspaceDirectoryReader workspaceDirectoryReader;

  @override
  final WorkspaceFileReader workspaceFileReader;

  @override
  McpServerStatusReader get mcpServerStatusReader =>
      const _StaticMcpServerStatusReader();

  @override
  ModelListReader get modelListReader => const _StaticModelListReader();

  @override
  PermissionProfileListReader get permissionProfileListReader =>
      const _StaticPermissionProfileListReader();

  @override
  SkillListReader get skillListReader => const _StaticSkillListReader();

  @override
  PluginListReader get pluginListReader => const _StaticPluginListReader();

  @override
  HookListReader get hookListReader => const _StaticHookListReader();

  @override
  AppListReader get appListReader => const _StaticAppListReader();

  @override
  ThreadMutationRunner get threadMutationRunner =>
      const _NoopThreadMutationRunner();

  @override
  ThreadBackgroundTerminalRunner get threadBackgroundTerminalRunner =>
      const _NoopThreadBackgroundTerminalRunner();

  @override
  ThreadGoalRunner get threadGoalRunner => const _NoopThreadGoalRunner();

  @override
  ThreadReviewRunner get threadReviewRunner => const _NoopThreadReviewRunner();

  @override
  TurnRunner get turnRunner => const _NoopTurnRunner();

  @override
  List<JsonRpcDiagnosticLogEntry> get diagnosticLogs => const [];

  @override
  Stream<CodexEvent> get events => const Stream.empty();

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Future<void> close({bool notifyApprovalController = true}) async {}
}

class _StaticConfigSnapshotReader implements CodexConfigSnapshotReader {
  const _StaticConfigSnapshotReader();

  @override
  Future<CodexConfigSnapshot> readConfig({
    bool includeLayers = true,
    String? cwd,
  }) async {
    return const CodexConfigSnapshot(config: {}, origins: {}, layers: []);
  }
}

class _StaticAccountSnapshotReader implements AccountSnapshotReader {
  const _StaticAccountSnapshotReader();

  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) async {
    return const AccountSnapshot(account: null, requiresOpenaiAuth: false);
  }
}

class _NoopAccountLogoutRunner implements AccountLogoutRunner {
  const _NoopAccountLogoutRunner();

  @override
  Future<void> logout() async {}
}

class _NoopFeedbackUploadRunner implements FeedbackUploadRunner {
  const _NoopFeedbackUploadRunner();

  @override
  Future<FeedbackUploadResult> uploadFeedback({
    required String classification,
    String? reason,
    String? threadId,
    String? turnId,
    bool includeLogs = false,
  }) async {
    return const FeedbackUploadResult(threadId: 'feedback_thread');
  }
}

class _NoopGitDiffReader implements GitDiffReader {
  const _NoopGitDiffReader();

  @override
  Future<GitDiffResult> readDiff({String? cwd}) async {
    return const GitDiffResult(isGitRepository: true, stat: '', diff: '');
  }
}

class _NoopFileSearchReader implements FileSearchReader {
  const _NoopFileSearchReader();

  @override
  Future<FileSearchResultPage> searchFiles({
    required String query,
    List<String> roots = const [],
    String? cancellationToken,
  }) async {
    return const FileSearchResultPage(files: []);
  }
}

class _NoopWorkspaceDirectoryReader implements WorkspaceDirectoryReader {
  const _NoopWorkspaceDirectoryReader();

  @override
  Future<WorkspaceDirectoryPage> listDirectory({
    required String root,
    String path = '',
    int limit = 100,
    String? cursor,
    bool includeHidden = false,
  }) async {
    return WorkspaceDirectoryPage(root: root, path: path, entries: const []);
  }
}

class _NoopWorkspaceFileReader implements WorkspaceFileReader {
  const _NoopWorkspaceFileReader();

  @override
  Future<WorkspaceFileStat> statFile({
    required String root,
    required String path,
  }) async {
    return WorkspaceFileStat(
      root: root,
      path: path,
      kind: WorkspaceFileKind.file,
    );
  }

  @override
  Future<WorkspaceFileReadChunk> readFile({
    required String root,
    required String path,
    int offset = 0,
    int limitBytes = 64 * 1024,
    String encoding = 'utf-8',
  }) async {
    return WorkspaceFileReadChunk(
      root: root,
      path: path,
      sizeBytes: 0,
      offset: offset,
      bytesRead: 0,
      nextOffset: null,
      hasMore: false,
      encoding: encoding,
      isBinary: false,
      content: '',
    );
  }
}

class _MapWorkspaceDirectoryReader implements WorkspaceDirectoryReader {
  const _MapWorkspaceDirectoryReader(this.entriesByPath);

  final Map<String, List<WorkspaceDirectoryEntry>> entriesByPath;

  @override
  Future<WorkspaceDirectoryPage> listDirectory({
    required String root,
    String path = '',
    int limit = 100,
    String? cursor,
    bool includeHidden = false,
  }) async {
    return WorkspaceDirectoryPage(
      root: root,
      path: path,
      entries: entriesByPath[path] ?? const [],
    );
  }
}

class _MapWorkspaceFileReader implements WorkspaceFileReader {
  const _MapWorkspaceFileReader({required this.stats, required this.chunks});

  final Map<String, WorkspaceFileStat> stats;
  final Map<String, List<WorkspaceFileReadChunk>> chunks;

  @override
  Future<WorkspaceFileStat> statFile({
    required String root,
    required String path,
  }) async {
    final stat = stats[path];
    if (stat == null) {
      throw StateError('Missing stat for $path');
    }
    return stat;
  }

  @override
  Future<WorkspaceFileReadChunk> readFile({
    required String root,
    required String path,
    int offset = 0,
    int limitBytes = 64 * 1024,
    String encoding = 'utf-8',
  }) async {
    final chunk = chunks[path]
        ?.where((chunk) => chunk.offset == offset)
        .firstOrNull;
    if (chunk == null) {
      throw StateError('Missing chunk for $path at $offset');
    }
    return chunk;
  }
}

class _StaticAccountUsageSnapshotReader implements AccountUsageSnapshotReader {
  const _StaticAccountUsageSnapshotReader();

  @override
  Future<AccountUsageSnapshot> readUsage() async {
    return const AccountUsageSnapshot(
      summary: AccountTokenUsageSummary(),
      dailyUsageBuckets: [],
      rateLimits: null,
      rateLimitsByLimitId: {},
      rateLimitResetCredits: null,
    );
  }
}

class _StaticMcpServerStatusReader implements McpServerStatusReader {
  const _StaticMcpServerStatusReader();

  @override
  Future<McpServerStatusPage> listMcpServers({
    String? threadId,
    String? cursor,
    int? limit,
    McpServerStatusDetail detail = McpServerStatusDetail.toolsAndAuthOnly,
  }) async {
    return const McpServerStatusPage(servers: []);
  }
}

class _StaticModelListReader implements ModelListReader {
  const _StaticModelListReader();

  @override
  Future<ModelListPage> listModels() async {
    return const ModelListPage(models: []);
  }
}

class _StaticPermissionProfileListReader
    implements PermissionProfileListReader {
  const _StaticPermissionProfileListReader();

  @override
  Future<PermissionProfileListPage> listPermissionProfiles({
    String? cwd,
  }) async {
    return const PermissionProfileListPage(profiles: []);
  }
}

class _StaticSkillListReader implements SkillListReader {
  const _StaticSkillListReader();

  @override
  Future<SkillListPage> listSkills({
    List<String> cwds = const [],
    bool forceReload = false,
  }) async {
    return const SkillListPage(entries: []);
  }
}

class _StaticPluginListReader implements PluginListReader {
  const _StaticPluginListReader();

  @override
  Future<PluginListPage> listPlugins({
    List<String> cwds = const [],
    List<PluginMarketplaceKind> marketplaceKinds = const [],
  }) async {
    return const PluginListPage(marketplaces: []);
  }
}

class _StaticHookListReader implements HookListReader {
  const _StaticHookListReader();

  @override
  Future<HookListPage> listHooks({List<String> cwds = const []}) async {
    return const HookListPage(entries: []);
  }
}

class _StaticAppListReader implements AppListReader {
  const _StaticAppListReader();

  @override
  Future<AppListPage> listApps({
    String? cursor,
    int? limit,
    String? threadId,
    bool forceRefetch = false,
  }) async {
    return const AppListPage(apps: []);
  }
}

class _StaticThreadListReader implements ThreadListReader {
  const _StaticThreadListReader(this.threads);

  final List<ThreadSummary> threads;

  @override
  Future<ThreadListPage> listThreads({int limit = 20}) async {
    return ThreadListPage(threads: threads);
  }
}

class _StaticThreadDetailReader implements ThreadDetailReader {
  const _StaticThreadDetailReader(this.detail);

  final ThreadDetail detail;

  @override
  Future<ThreadDetail> readThread({
    required String threadId,
    bool includeTurns = true,
  }) async => detail;
}

class _NoopTurnRunner implements TurnRunner {
  const _NoopTurnRunner();

  @override
  Future<ThreadSummary> startThread() {
    throw UnimplementedError();
  }

  @override
  Future<ThreadSummary> resumeThread({required String threadId}) {
    throw UnimplementedError();
  }

  @override
  Future<TurnSummary> startTurn({
    required String threadId,
    required String text,
    CodexConfigOverrides overrides = CodexConfigOverrides.empty,
    List<TurnTextElement> textElements = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> interruptTurn({
    required String threadId,
    required String turnId,
  }) {
    throw UnimplementedError();
  }
}

class _NoopThreadMutationRunner implements ThreadMutationRunner {
  const _NoopThreadMutationRunner();

  @override
  Future<ThreadSummary> forkThread({
    required String threadId,
    String? lastTurnId,
    bool ephemeral = false,
  }) async {
    return ThreadSummary.fromJson({
      'id': 'thr_fork',
      'sessionId': 'sess_1',
      'preview': 'Forked thread',
      'ephemeral': ephemeral,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'forkedFromId': threadId,
    });
  }

  @override
  Future<ThreadSummary> startSideConversation({
    required String threadId,
  }) async {
    return ThreadSummary.fromJson({
      'id': 'thr_side',
      'sessionId': 'sess_1',
      'preview': 'Side thread',
      'ephemeral': true,
      'status': 'idle',
      'cwd': '/repo',
      'updatedAt': 1,
      'forkedFromId': threadId,
    });
  }

  @override
  Future<void> compactThread({required String threadId}) async {}

  @override
  Future<void> setThreadName({
    required String threadId,
    required String name,
  }) async {}

  @override
  Future<void> archiveThread({required String threadId}) async {}

  @override
  Future<void> deleteThread({required String threadId}) async {}
}

class _NoopThreadBackgroundTerminalRunner
    implements ThreadBackgroundTerminalRunner {
  const _NoopThreadBackgroundTerminalRunner();

  @override
  Future<ThreadBackgroundTerminalPage> listTerminals({
    required String threadId,
    String? cursor,
    int? limit,
  }) async {
    return const ThreadBackgroundTerminalPage(terminals: []);
  }

  @override
  Future<void> cleanTerminals({required String threadId}) async {}
}

class _NoopThreadGoalRunner implements ThreadGoalRunner {
  const _NoopThreadGoalRunner();

  @override
  Future<ThreadGoalGetResult> getGoal({required String threadId}) async {
    return const ThreadGoalGetResult();
  }

  @override
  Future<ThreadGoalSetResult> setGoal({
    required String threadId,
    String? objective,
    String? status,
    int? tokenBudget,
  }) async {
    return ThreadGoalSetResult(
      goal: ThreadGoal(
        threadId: threadId,
        objective: objective ?? 'Goal',
        status: status ?? 'active',
        tokenBudget: tokenBudget,
        tokensUsed: 0,
        timeUsedSeconds: 0,
        createdAtSeconds: 1,
        updatedAtSeconds: 1,
        raw: const {},
      ),
    );
  }

  @override
  Future<ThreadGoalClearResult> clearGoal({required String threadId}) async {
    return const ThreadGoalClearResult(cleared: false);
  }
}

class _NoopThreadReviewRunner implements ThreadReviewRunner {
  const _NoopThreadReviewRunner();

  @override
  Future<ThreadReviewStartResult> startReview({
    required String threadId,
    required ThreadReviewTarget target,
    ThreadReviewDelivery? delivery,
  }) async {
    return ThreadReviewStartResult(
      reviewThreadId: threadId,
      turn: TurnSummary.fromJson({
        'id': 'turn_review',
        'status': 'inProgress',
        'items': <Object?>[],
        'itemsView': 'notLoaded',
      }),
    );
  }
}
