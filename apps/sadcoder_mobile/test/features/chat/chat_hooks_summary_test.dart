import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_hooks_summary.dart';
import 'package:sadcoder_mobile/src/hooks/hook_list_reader.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  const l10n = AppLocalizations(Locale('en'));

  test('buildHooksSummary renders hooks and diagnostics', () {
    final summary = buildHooksSummary(
      l10n: l10n,
      page: HookListPage.fromJson({
        'data': [
          {
            'cwd': '/repo',
            'hooks': [
              {
                'key': 'pre-tool-use-shell',
                'eventName': 'preToolUse',
                'handlerType': 'command',
                'matcher': 'shell',
                'command': 'scripts/check.sh',
                'timeoutSec': 30,
                'statusMessage': 'Checking shell command',
                'sourcePath': '/repo/.codex/hooks.json',
                'source': 'project',
                'pluginId': 'guardrails',
                'displayOrder': 1,
                'enabled': true,
                'isManaged': false,
                'currentHash': 'abc123',
                'trustStatus': 'trusted',
              },
            ],
            'warnings': ['deprecated hook shape'],
            'errors': [
              {
                'path': '/repo/.codex/bad-hooks.json',
                'message': 'invalid hook',
              },
            ],
          },
        ],
      }),
    );

    expect(summary, contains('Hooks'));
    expect(summary, contains('cwd: /repo'));
    expect(
      summary,
      contains(
        'preToolUse (pre-tool-use-shell): command, enabled, user-managed',
      ),
    );
    expect(summary, contains('trust: trusted'));
    expect(summary, contains('source: project'));
    expect(summary, contains('matcher: shell'));
    expect(summary, contains('command: scripts/check.sh'));
    expect(summary, contains('status message: Checking shell command'));
    expect(summary, contains('source path: /repo/.codex/hooks.json'));
    expect(summary, contains('plugin: guardrails'));
    expect(summary, contains('timeout: 30s'));
    expect(summary, contains('deprecated hook shape'));
    expect(summary, contains('/repo/.codex/bad-hooks.json: invalid hook'));
  });

  test('buildHooksSummary returns a concise empty state', () {
    final summary = buildHooksSummary(
      l10n: l10n,
      page: const HookListPage(entries: []),
    );

    expect(summary, 'Hooks\nNo hooks configured.');
  });
}
