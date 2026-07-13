import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_agent_topology_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';
import 'package:sadcoder_mobile/src/threads/agent_thread_topology.dart';
import 'package:sadcoder_mobile/src/threads/thread_summary.dart';

void main() {
  testWidgets('renders agent topology and returns tapped thread', (
    tester,
  ) async {
    final main = _thread(id: 'thr_main', title: 'Main thread');
    final worker = _thread(
      id: 'thr_worker',
      title: 'Build patch',
      status: 'running',
      nickname: 'Builder',
      role: 'coder',
    );
    final entries = [
      AgentThreadTopologyEntry(
        thread: main,
        depth: 0,
        hasChildren: true,
        runtimeStatus: AgentThreadRuntimeStatus.running,
      ),
      AgentThreadTopologyEntry(
        thread: worker,
        depth: 1,
        hasChildren: false,
        parentThreadId: 'thr_main',
        ancestorThreadId: 'thr_main',
        agentPath: 'agents/build',
        runtimeStatus: AgentThreadRuntimeStatus.errored,
      ),
    ];

    await tester.pumpWidget(
      _TopologyHarness(
        entries: entries,
        activeThreadId: 'thr_main',
        subagentsOnly: false,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-agent-topology-sheet')));
    await tester.pumpAndSettle();

    expect(find.text('Agent threads'), findsOneWidget);
    expect(find.text('Main thread (active)'), findsOneWidget);
    expect(find.text('Build patch'), findsOneWidget);
    expect(find.textContaining('Status: errored'), findsOneWidget);
    expect(find.textContaining('Agent: Builder / coder'), findsOneWidget);
    expect(find.textContaining('Agent path: agents/build'), findsOneWidget);
    expect(find.textContaining('Parent thread: thr_main'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('agent-thread-thr_worker')));
    await tester.pumpAndSettle();

    expect(find.text('Selected: thr_worker'), findsOneWidget);
  });

  testWidgets('uses subagent title when filtered to subagents', (tester) async {
    await tester.pumpWidget(
      _TopologyHarness(
        entries: [
          AgentThreadTopologyEntry(
            thread: _thread(id: 'thr_worker', title: 'Build patch'),
            depth: 1,
            hasChildren: false,
            parentThreadId: 'thr_main',
          ),
        ],
        subagentsOnly: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-agent-topology-sheet')));
    await tester.pumpAndSettle();

    expect(find.text('Subagents'), findsOneWidget);
    expect(find.text('Agent threads'), findsNothing);
  });
}

class _TopologyHarness extends StatefulWidget {
  const _TopologyHarness({
    required this.entries,
    this.subagentsOnly = false,
    this.activeThreadId,
  });

  final List<AgentThreadTopologyEntry> entries;
  final bool subagentsOnly;
  final String? activeThreadId;

  @override
  State<_TopologyHarness> createState() => _TopologyHarnessState();
}

class _TopologyHarnessState extends State<_TopologyHarness> {
  ThreadSummary? _selectedThread;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: sadCoderThemeData(
        colorPalette: AppColorPalette.sadcoder,
        brightness: Brightness.light,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    key: const ValueKey('open-agent-topology-sheet'),
                    onPressed: () async {
                      final selected =
                          await showModalBottomSheet<ThreadSummary>(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => ChatAgentTopologySheet(
                              entries: widget.entries,
                              subagentsOnly: widget.subagentsOnly,
                              activeThreadId: widget.activeThreadId,
                            ),
                          );
                      if (mounted) {
                        setState(() => _selectedThread = selected);
                      }
                    },
                    child: const Text('Open'),
                  ),
                  Text(
                    _selectedThread == null
                        ? 'No selection'
                        : 'Selected: ${_selectedThread!.id}',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

ThreadSummary _thread({
  required String id,
  required String title,
  String status = 'idle',
  String? nickname,
  String? role,
}) {
  return ThreadSummary(
    id: id,
    sessionId: 'sess_1',
    preview: title,
    ephemeral: false,
    status: status,
    cwd: '/repo',
    updatedAtSeconds: 1,
    agentNickname: nickname,
    agentRole: role,
  );
}
