import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/experimental_features/experimental_feature_runner.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_experimental_feature_command.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('command loads the selected thread catalog and opens settings', (
    tester,
  ) async {
    final runner = _RecordingExperimentalFeatureRunner();

    await tester.pumpWidget(_Harness(runner: runner));
    await tester.tap(find.byKey(const ValueKey('run-experimental-command')));
    await tester.pumpAndSettle();

    expect(runner.threadIds, ['thread-1']);
    expect(find.text('Network proxy'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('experimental-feature-close')));
    await tester.pumpAndSettle();

    expect(
      find.text('No experimental feature settings changed.'),
      findsOneWidget,
    );
  });
}

class _RecordingExperimentalFeatureRunner implements ExperimentalFeatureRunner {
  final threadIds = <String?>[];

  @override
  Future<List<ExperimentalFeature>> listFeatures({String? threadId}) async {
    threadIds.add(threadId);
    return const [
      ExperimentalFeature(
        name: 'network_proxy',
        stage: ExperimentalFeatureStage.beta,
        displayName: 'Network proxy',
        enabled: false,
        defaultEnabled: false,
      ),
    ];
  }

  @override
  Future<ExperimentalFeatureWriteResult> setFeatureEnabled({
    required String featureName,
    required bool enabled,
    String? expectedVersion,
  }) {
    throw UnimplementedError();
  }
}

class _Harness extends StatefulWidget {
  const _Harness({required this.runner});

  final ExperimentalFeatureRunner runner;

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
                key: const ValueKey('run-experimental-command'),
                onPressed: () async {
                  final result = await showExperimentalFeaturesFromCommand(
                    context: context,
                    runner: widget.runner,
                    configController: null,
                    cwds: const ['/repo'],
                    threadId: 'thread-1',
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
