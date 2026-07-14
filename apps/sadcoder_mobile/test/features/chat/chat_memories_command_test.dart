import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_memories_command.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/memories/memory_runner.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('command opens controls when thread memory metadata is present', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(runner: _FakeMemoryRunner()));
    await tester.tap(find.byKey(const ValueKey('run-memories-command')));
    await tester.pumpAndSettle();

    expect(find.text('Use memories in this thread'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('memories-close')));
    await tester.pumpAndSettle();
    expect(find.text('No memory settings changed.'), findsOneWidget);
  });
}

class _FakeMemoryRunner implements MemoryRunner {
  @override
  Future<void> resetMemory() async {}

  @override
  Future<void> setThreadMemoryMode({
    required String threadId,
    required ThreadMemoryMode mode,
  }) async {}
}

class _Harness extends StatefulWidget {
  const _Harness({required this.runner});

  final MemoryRunner runner;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String? _result;

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
          builder: (context) => Column(
            children: [
              FilledButton(
                key: const ValueKey('run-memories-command'),
                onPressed: () async {
                  final result = await showMemoriesFromCommand(
                    context: context,
                    runner: widget.runner,
                    configController: null,
                    cwds: const ['/repo'],
                    threadId: 'thread-1',
                    threadRaw: const {'memoryMode': 'disabled'},
                    arguments: '',
                  );
                  if (mounted) {
                    setState(() => _result = result);
                  }
                },
                child: const Text('Run'),
              ),
              if (_result != null) Text(_result!),
            ],
          ),
        ),
      ),
    );
  }
}
