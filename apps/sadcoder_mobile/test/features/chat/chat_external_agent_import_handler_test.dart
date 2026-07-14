import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/commands/slash_command_action_dispatcher.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/external_agents/external_agent_config_runner.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_external_agent_import_handler.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  testWidgets('detects, selects, confirms, and starts a Claude import', (
    tester,
  ) async {
    final events = StreamController<CodexEvent>.broadcast();
    addTearDown(events.close);
    final runner = _FakeExternalAgentConfigRunner(
      items: [
        _item('CONFIG', 'Import user configuration'),
        _item('HOOKS', 'Import workspace hooks', cwd: '/repo'),
      ],
      histories: [
        ExternalAgentConfigImportHistory.fromJson({
          'importId': 'previous',
          'completedAtMs': 1000,
          'successes': [
            {'itemType': 'CONFIG'},
            {'itemType': 'SKILLS'},
          ],
          'failures': [
            {
              'itemType': 'HOOKS',
              'failureStage': 'write',
              'message': 'Previous hook failure',
            },
          ],
        })!,
      ],
    );
    await tester.pumpWidget(
      _ImportHarness(runner: runner, events: events.stream),
    );

    await tester.tap(find.byKey(const ValueKey('open-external-agent-import')));
    await tester.pumpAndSettle();

    expect(runner.detectedCwds, ['/repo']);
    expect(find.text('Import from Claude Code'), findsOneWidget);
    expect(find.text('Import user configuration'), findsOneWidget);
    expect(find.textContaining('Workspace: /repo'), findsOneWidget);
    expect(find.text('Recent imports'), findsOneWidget);
    expect(find.text('2 succeeded, 1 failed'), findsOneWidget);
    await tester.tap(find.text('2 succeeded, 1 failed'));
    await tester.pumpAndSettle();
    expect(find.text('Previous hook failure'), findsOneWidget);
    await tester.tap(find.text('2 succeeded, 1 failed'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('external-agent-import-item-1')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('external-agent-import-continue')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirm server import'), findsOneWidget);
    expect(find.textContaining('Import 1 selected groups'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('external-agent-import-confirm')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(runner.importedItems.single.rawType, 'CONFIG');
    expect(runner.importSource, 'claude');
    expect(find.text('Import in progress'), findsOneWidget);

    events.add(
      CodexEvent.fromNotification({
        'method': 'externalAgentConfig/import/progress',
        'params': {
          'importId': 'import_1',
          'itemTypeResults': [
            {
              'itemType': 'CONFIG',
              'successes': [
                {
                  'itemType': 'CONFIG',
                  'target': '/home/test/.codex/config.toml',
                },
              ],
              'failures': <Object?>[],
            },
          ],
        },
      }),
    );
    await tester.pump();
    expect(find.text('/home/test/.codex/config.toml'), findsOneWidget);

    events.add(
      CodexEvent.fromNotification({
        'method': 'externalAgentConfig/import/completed',
        'params': {
          'importId': 'import_1',
          'itemTypeResults': [
            {
              'itemType': 'CONFIG',
              'successes': [
                {
                  'itemType': 'CONFIG',
                  'target': '/home/test/.codex/config.toml',
                },
              ],
              'failures': [
                {
                  'itemType': 'CONFIG',
                  'failureStage': 'write',
                  'message': 'Could not import one setting',
                },
              ],
            },
          ],
        },
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import completed'), findsOneWidget);
    expect(find.text('1 succeeded, 1 failed'), findsOneWidget);
    expect(find.text('Could not import one setting'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('external-agent-import-progress-close')),
    );
    await tester.pumpAndSettle();
    expect(find.text('executed'), findsOneWidget);
  });

  testWidgets('empty detection can close without starting an import', (
    tester,
  ) async {
    final runner = _FakeExternalAgentConfigRunner(items: const []);
    await tester.pumpWidget(_ImportHarness(runner: runner));

    await tester.tap(find.byKey(const ValueKey('open-external-agent-import')));
    await tester.pumpAndSettle();

    expect(
      find.text('No importable Claude Code data was found.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(runner.importedItems, isEmpty);
    expect(find.text('cancelled'), findsOneWidget);
  });

  testWidgets('shows a blocking scan state while detection is pending', (
    tester,
  ) async {
    final detection = Completer<ExternalAgentConfigDetection>();
    final runner = _FakeExternalAgentConfigRunner(
      items: const [],
      detectionCompleter: detection,
    );
    await tester.pumpWidget(_ImportHarness(runner: runner));

    await tester.tap(find.byKey(const ValueKey('open-external-agent-import')));
    await tester.pump();

    expect(find.text('Scanning the selected host...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    detection.complete(const ExternalAgentConfigDetection(items: []));
    await tester.pumpAndSettle();
    expect(
      find.text('No importable Claude Code data was found.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('keeps the Chinese selection sheet inside a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runner = _FakeExternalAgentConfigRunner(
      items: [
        _item(
          'MCP_SERVER_CONFIG',
          '导入工作区中名称很长的 MCP 服务器配置和相关连接设置',
          cwd: r'C:\workspace\mobile-project',
        ),
      ],
    );
    await tester.pumpWidget(
      _ImportHarness(runner: runner, locale: const Locale('zh', 'CN')),
    );

    await tester.tap(find.byKey(const ValueKey('open-external-agent-import')));
    await tester.pumpAndSettle();

    expect(find.text('从 Claude Code 导入'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('external-agent-import-continue')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
  });
}

ExternalAgentConfigMigrationItem _item(
  String type,
  String description, {
  String? cwd,
}) {
  return ExternalAgentConfigMigrationItem.fromJson({
    'itemType': type,
    'description': description,
    'cwd': cwd,
  })!;
}

class _ImportHarness extends StatefulWidget {
  const _ImportHarness({
    required this.runner,
    this.events,
    this.locale = const Locale('en', 'US'),
  });

  final ExternalAgentConfigRunner runner;
  final Stream<CodexEvent>? events;
  final Locale locale;

  @override
  State<_ImportHarness> createState() => _ImportHarnessState();
}

class _ImportHarnessState extends State<_ImportHarness> {
  SlashCommandCallbackResult? result;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: widget.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              FilledButton(
                key: const ValueKey('open-external-agent-import'),
                onPressed: () async {
                  final next = await ChatExternalAgentImportHandler(
                    context: context,
                    mounted: () => mounted,
                    runner: widget.runner,
                    currentWorkspaceCwdsProvider: () => ['/repo'],
                    events: widget.events,
                  ).importFromClaudeCode();
                  if (mounted) {
                    setState(() => result = next);
                  }
                },
                child: const Text('Open'),
              ),
              if (result != null) Text(result!.name),
            ],
          ),
        ),
      ),
    );
  }
}

class _FakeExternalAgentConfigRunner implements ExternalAgentConfigRunner {
  _FakeExternalAgentConfigRunner({
    required this.items,
    this.detectionCompleter,
    this.histories = const [],
  });

  final List<ExternalAgentConfigMigrationItem> items;
  final Completer<ExternalAgentConfigDetection>? detectionCompleter;
  final List<ExternalAgentConfigImportHistory> histories;
  List<String> detectedCwds = const [];
  List<ExternalAgentConfigMigrationItem> importedItems = const [];
  String? importSource;

  @override
  Future<ExternalAgentConfigDetection> detect({
    bool includeHome = true,
    List<String> cwds = const [],
  }) async {
    expect(includeHome, isTrue);
    detectedCwds = List.of(cwds);
    final pendingDetection = detectionCompleter;
    if (pendingDetection != null) {
      return pendingDetection.future;
    }
    return ExternalAgentConfigDetection(items: items);
  }

  @override
  Future<List<ExternalAgentConfigImportHistory>> readImportHistories() async {
    return histories;
  }

  @override
  Future<ExternalAgentConfigImportStart> startImport({
    required List<ExternalAgentConfigMigrationItem> items,
    String? source,
  }) async {
    importedItems = List.of(items);
    importSource = source;
    return const ExternalAgentConfigImportStart(importId: 'import_1', raw: {});
  }
}
