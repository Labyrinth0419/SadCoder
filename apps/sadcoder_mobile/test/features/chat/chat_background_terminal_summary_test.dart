import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/background_terminals/thread_background_terminal.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_background_terminal_summary.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  test('formats terminal numbers and memory through localizations', () {
    const en = AppLocalizations(Locale('en'));
    const zh = AppLocalizations(Locale('zh'));
    final page = ThreadBackgroundTerminalPage.fromJson({
      'data': [
        {
          'itemId': 'item_1',
          'processId': 'proc_1',
          'command': 'python3 -m http.server',
          'cwd': '/repo',
          'osPid': 1234,
          'cpuPercent': 12.5,
          'rssKb': 2048,
        },
      ],
    });

    final english = buildThreadBackgroundTerminalsSummary(
      l10n: en,
      page: page,
    );
    final chinese = buildThreadBackgroundTerminalsSummary(
      l10n: zh,
      page: page,
    );

    expect(english, contains('OS pid: 1,234'));
    expect(english, contains('CPU: 12.5%'));
    expect(english, contains('memory: 2 MB'));
    expect(chinese, contains('系统进程 ID: 1,234'));
    expect(chinese, contains('CPU: 12.5%'));
    expect(chinese, contains('内存: 2 MB'));
  });
}
