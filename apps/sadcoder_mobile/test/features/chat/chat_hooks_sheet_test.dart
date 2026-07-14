import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_hooks_sheet.dart';
import 'package:sadcoder_mobile/src/hooks/hook_list_reader.dart';
import 'package:sadcoder_mobile/src/hooks/hook_mutation_runner.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  testWidgets('manages user hooks with confirmation and reload', (
    tester,
  ) async {
    final reader = _RecordingHookReader();
    final mutationRunner = _RecordingHookMutationRunner(reader);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showChatHooksSheet(
                  context: context,
                  reader: reader,
                  mutationRunner: mutationRunner,
                  cwds: const ['/repo'],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Hooks'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-hook-enabled-hook.key\\path')),
      findsOneWidget,
    );
    expect(reader.cwds, [
      ['/repo'],
    ]);

    await tester.tap(
      find.byKey(const ValueKey('chat-hook-enabled-hook.key\\path')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm hook change'), findsOneWidget);
    expect(mutationRunner.enabledCalls, isEmpty);

    await tester.tap(find.text('Disable'));
    await tester.pumpAndSettle();

    expect(mutationRunner.enabledCalls, [
      (key: 'hook.key\\path', enabled: false),
    ]);
    expect(reader.cwds, [
      ['/repo'],
      ['/repo'],
    ]);

    await tester.tap(
      find.byKey(const ValueKey('chat-hook-trust-hook.key\\path')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm hook change'), findsOneWidget);
    await tester.tap(find.text('trust'));
    await tester.pumpAndSettle();

    expect(mutationRunner.trustCalls, [
      (key: 'hook.key\\path', hash: 'hash-1'),
    ]);
  });
}

class _RecordingHookReader implements HookListReader {
  final cwds = <List<String>>[];
  bool enabled = true;
  String trustStatus = 'untrusted';

  @override
  Future<HookListPage> listHooks({List<String> cwds = const []}) async {
    this.cwds.add(List.unmodifiable(cwds));
    return HookListPage(
      entries: [
        HookListEntry(
          cwd: '/repo',
          hooks: [
            HookSummary(
              key: r'hook.key\path',
              eventName: 'PreToolUse',
              handlerType: 'command',
              timeoutSec: 5,
              sourcePath: '/repo/hooks.json',
              source: 'user',
              displayOrder: 0,
              enabled: enabled,
              isManaged: false,
              currentHash: 'hash-1',
              trustStatus: trustStatus,
              command: 'echo test',
              raw: const {},
            ),
          ],
          warnings: const [],
          errors: const [],
          raw: const {},
        ),
      ],
    );
  }
}

class _RecordingHookMutationRunner implements HookMutationRunner {
  _RecordingHookMutationRunner(this.reader);

  final _RecordingHookReader reader;
  final enabledCalls = <({String key, bool enabled})>[];
  final trustCalls = <({String key, String hash})>[];

  @override
  Future<HookMutationResult> setHookEnabled({
    required String hookKey,
    required bool enabled,
  }) async {
    enabledCalls.add((key: hookKey, enabled: enabled));
    reader.enabled = enabled;
    return const HookMutationResult(raw: {});
  }

  @override
  Future<HookMutationResult> trustHook({
    required String hookKey,
    required String currentHash,
  }) async {
    trustCalls.add((key: hookKey, hash: currentHash));
    reader.trustStatus = 'trusted';
    return const HookMutationResult(raw: {});
  }
}
