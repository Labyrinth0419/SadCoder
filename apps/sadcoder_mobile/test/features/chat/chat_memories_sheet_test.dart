import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_memories_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/memories/memory_runner.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('confirms thread mode changes and destructive memory reset', (
    tester,
  ) async {
    final runner = _FakeMemoryRunner();

    await tester.pumpWidget(_Harness(runner: runner));
    await tester.tap(find.byKey(const ValueKey('open-memories-sheet')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('memories-thread-mode')));
    await tester.pumpAndSettle();
    expect(find.text('Change thread memory mode?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('memories-mode-confirm')));
    await tester.pumpAndSettle();
    expect(runner.modeWrites, [('thread-1', ThreadMemoryMode.enabled)]);

    await tester.tap(find.byKey(const ValueKey('memories-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Reset all server memories?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('memories-reset-confirm')));
    await tester.pumpAndSettle();
    expect(runner.resetCount, 1);

    await tester.tap(find.byKey(const ValueKey('memories-close')));
    await tester.pumpAndSettle();
  });
}

class _FakeMemoryRunner implements MemoryRunner {
  final modeWrites = <(String, ThreadMemoryMode)>[];
  var resetCount = 0;

  @override
  Future<void> resetMemory() async {
    resetCount++;
  }

  @override
  Future<void> setThreadMemoryMode({
    required String threadId,
    required ThreadMemoryMode mode,
  }) async {
    modeWrites.add((threadId, mode));
  }
}

class _Harness extends StatelessWidget {
  const _Harness({required this.runner});

  final MemoryRunner runner;

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
          builder: (context) => Center(
            child: FilledButton(
              key: const ValueKey('open-memories-sheet'),
              onPressed: () => showModalBottomSheet<int>(
                context: context,
                isScrollControlled: true,
                builder: (context) => ChatMemoriesSheet(
                  runner: runner,
                  threadId: 'thread-1',
                  initialMode: ThreadMemoryMode.disabled,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }
}
