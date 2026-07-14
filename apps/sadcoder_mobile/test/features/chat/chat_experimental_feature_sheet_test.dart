import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/experimental_features/experimental_feature_runner.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_experimental_feature_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('shows beta features and confirms persistent changes', (
    tester,
  ) async {
    final runner = _FakeExperimentalFeatureRunner([
      const ExperimentalFeature(
        name: 'network_proxy',
        stage: ExperimentalFeatureStage.beta,
        displayName: 'Network proxy',
        description: 'Restrict network access.',
        enabled: false,
        defaultEnabled: false,
      ),
      const ExperimentalFeature(
        name: 'stable_feature',
        stage: ExperimentalFeatureStage.stable,
        enabled: true,
        defaultEnabled: true,
      ),
    ]);

    await tester.pumpWidget(_Harness(runner: runner));
    await tester.tap(find.byKey(const ValueKey('open-experimental-sheet')));
    await tester.pumpAndSettle();

    expect(find.text('Network proxy'), findsOneWidget);
    expect(find.text('stable_feature'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('experimental-feature-network_proxy')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Change experimental feature?'), findsOneWidget);
    expect(find.textContaining('Current: disabled'), findsOneWidget);
    expect(find.textContaining('New: enabled'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('experimental-feature-confirm')),
    );
    await tester.pumpAndSettle();

    expect(runner.writes, [('network_proxy', true)]);
    expect(runner.expectedVersions, ['v1']);
    expect(find.text('Updated Network proxy.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('experimental-feature-close')));
    await tester.pumpAndSettle();
  });
}

class _FakeExperimentalFeatureRunner implements ExperimentalFeatureRunner {
  _FakeExperimentalFeatureRunner(this.features);

  List<ExperimentalFeature> features;
  final writes = <(String, bool)>[];
  final expectedVersions = <String?>[];

  @override
  Future<List<ExperimentalFeature>> listFeatures({String? threadId}) async =>
      features;

  @override
  Future<ExperimentalFeatureWriteResult> setFeatureEnabled({
    required String featureName,
    required bool enabled,
    String? expectedVersion,
  }) async {
    writes.add((featureName, enabled));
    expectedVersions.add(expectedVersion);
    features = [
      for (final feature in features)
        if (feature.name == featureName)
          ExperimentalFeature(
            name: feature.name,
            stage: feature.stage,
            enabled: enabled,
            defaultEnabled: feature.defaultEnabled,
            displayName: feature.displayName,
            description: feature.description,
            announcement: feature.announcement,
          )
        else
          feature,
    ];
    return const ExperimentalFeatureWriteResult(
      status: 'ok',
      version: 'v2',
      filePath: '/config.toml',
      raw: {},
    );
  }
}

class _Harness extends StatelessWidget {
  const _Harness({required this.runner});

  final _FakeExperimentalFeatureRunner runner;

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
              key: const ValueKey('open-experimental-sheet'),
              onPressed: () => showModalBottomSheet<int>(
                context: context,
                isScrollControlled: true,
                builder: (context) => ChatExperimentalFeatureSheet(
                  runner: runner,
                  features: runner.features,
                  expectedVersion: 'v1',
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
