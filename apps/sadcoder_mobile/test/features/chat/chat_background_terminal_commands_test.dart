import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal_runner.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_background_terminal_commands.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test(
    'background terminals command lists terminals for current thread',
    () async {
      final runner = _RecordingBackgroundTerminalRunner(
        page: ThreadBackgroundTerminalPage.fromJson({
          'data': [
            {
              'itemId': 'item_1',
              'processId': 'proc_1',
              'command': 'npm test',
              'cwd': '/repo',
            },
          ],
        }),
      );

      final summary = await buildBackgroundTerminalsSummaryFromCommand(
        l10n: l10n,
        runner: runner,
        threadId: 'thr_1',
        arguments: '',
      );

      expect(summary, contains('Background terminals'));
      expect(summary, contains('process proc_1: npm test'));
      expect(runner.listCalls, hasLength(1));
      expect(runner.listCalls.single.threadId, 'thr_1');
      expect(runner.listCalls.single.limit, 25);
      expect(runner.cleanCalls, isEmpty);
    },
  );

  test(
    'background terminals command rejects arguments and missing context',
    () async {
      final runner = _RecordingBackgroundTerminalRunner();

      final unsupported = await buildBackgroundTerminalsSummaryFromCommand(
        l10n: l10n,
        runner: runner,
        threadId: 'thr_1',
        arguments: 'verbose',
      );
      final missingRunner = await buildBackgroundTerminalsSummaryFromCommand(
        l10n: l10n,
        runner: null,
        threadId: 'thr_1',
        arguments: '',
      );
      final missingThread = await buildBackgroundTerminalsSummaryFromCommand(
        l10n: l10n,
        runner: runner,
        threadId: null,
        arguments: '',
      );

      expect(unsupported, isNull);
      expect(missingRunner, isNull);
      expect(missingThread, isNull);
      expect(runner.listCalls, isEmpty);
    },
  );

  test('clean background terminals command cleans current thread', () async {
    final runner = _RecordingBackgroundTerminalRunner();

    final summary = await cleanBackgroundTerminalsFromCommand(
      l10n: l10n,
      runner: runner,
      threadId: 'thr_1',
      arguments: '',
    );

    expect(summary, 'Stopping all background terminals.');
    expect(runner.cleanCalls, ['thr_1']);
    expect(runner.listCalls, isEmpty);
  });

  test(
    'clean background terminals command rejects unavailable inputs',
    () async {
      final runner = _RecordingBackgroundTerminalRunner();

      final unsupported = await cleanBackgroundTerminalsFromCommand(
        l10n: l10n,
        runner: runner,
        threadId: 'thr_1',
        arguments: 'now',
      );
      final missingRunner = await cleanBackgroundTerminalsFromCommand(
        l10n: l10n,
        runner: null,
        threadId: 'thr_1',
        arguments: '',
      );
      final missingThread = await cleanBackgroundTerminalsFromCommand(
        l10n: l10n,
        runner: runner,
        threadId: null,
        arguments: '',
      );

      expect(unsupported, isNull);
      expect(missingRunner, isNull);
      expect(missingThread, isNull);
      expect(runner.cleanCalls, isEmpty);
    },
  );
}

class _RecordingBackgroundTerminalRunner
    implements ThreadBackgroundTerminalRunner {
  _RecordingBackgroundTerminalRunner({
    this.page = const ThreadBackgroundTerminalPage(terminals: []),
  });

  final ThreadBackgroundTerminalPage page;
  final listCalls = <({String threadId, String? cursor, int? limit})>[];
  final cleanCalls = <String>[];

  @override
  Future<ThreadBackgroundTerminalPage> listTerminals({
    required String threadId,
    String? cursor,
    int? limit,
  }) async {
    listCalls.add((threadId: threadId, cursor: cursor, limit: limit));
    return page;
  }

  @override
  Future<void> cleanTerminals({required String threadId}) async {
    cleanCalls.add(threadId);
  }
}
