import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/models/model_labels.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';

void main() {
  testWidgets('localizes model capability default summaries', (tester) async {
    const model = CodexModelSummary(
      id: 'gpt-5.6-sol',
      supportedReasoningEfforts: [
        CodexModelReasoningEffort(id: 'low', description: 'Fast'),
        CodexModelReasoningEffort(id: 'high', description: 'Deep'),
      ],
      defaultReasoningEffort: 'low',
      serviceTiers: [
        CodexModelServiceTier(id: 'default', name: 'Default'),
        CodexModelServiceTier(id: 'priority', name: 'Priority'),
      ],
      defaultServiceTier: 'priority',
    );

    expect(
      await _capabilitySummary(tester, const Locale('en', 'US'), model),
      'Reasoning: low, high (default: low) · '
      'Service tiers: Default, Priority (default: priority)',
    );
    expect(
      await _capabilitySummary(tester, const Locale('zh', 'CN'), model),
      '推理：low, high (默认：low) · '
      '服务档位：Default, Priority (默认：priority)',
    );
  });
}

Future<String?> _capabilitySummary(
  WidgetTester tester,
  Locale locale,
  CodexModelSummary model,
) async {
  String? summary;
  await tester.pumpWidget(
    Localizations(
      locale: locale,
      delegates: const [
        AppLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Builder(
        builder: (context) {
          summary = codexModelCapabilitySummary(context, model);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump();
  return summary;
}
