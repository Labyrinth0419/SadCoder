import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_model_override_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/models/model_list_controller.dart';
import 'package:sadcoder_mobile/src/models/model_list_reader.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('loads model list and returns selected turn override', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final modelReader = _RecordingModelListReader(
      page: const ModelListPage(
        models: [
          CodexModelSummary(
            id: 'gpt-5-codex',
            name: 'GPT-5 Codex',
            provider: 'openai',
            isDefault: true,
            supportedReasoningEfforts: [
              CodexModelReasoningEffort(id: 'low', description: 'Fast'),
              CodexModelReasoningEffort(id: 'medium', description: 'Balanced'),
              CodexModelReasoningEffort(id: 'high', description: 'Deep'),
            ],
            defaultReasoningEffort: 'medium',
          ),
        ],
      ),
    );
    final modelListController = ModelListController(
      readerProvider: () => modelReader,
    );
    addTearDown(modelListController.dispose);
    addTearDown(overrideController.dispose);

    await tester.pumpWidget(
      _ModelSheetHarness(
        overrideController: overrideController,
        modelListController: modelListController,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-chat-model-sheet')));
    await tester.pumpAndSettle();

    expect(modelReader.calls, 1);
    expect(
      find.byKey(const ValueKey('chat-model-command-model-list')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('chat-model-command-model-list')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GPT-5 Codex (openai) (default)').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('chat-model-command-effort-list')),
      findsOneWidget,
    );
    expect(find.text('Server default (medium)'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('chat-model-command-effort-list')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Balanced'), findsOneWidget);
    await tester.tap(find.text('high').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-model-command-apply')));
    await tester.pumpAndSettle();

    expect(find.text('turn / gpt-5-codex / high'), findsOneWidget);
  });

  testWidgets('switching models clears an unsupported reasoning effort', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final modelReader = _RecordingModelListReader(
      page: const ModelListPage(
        models: [
          CodexModelSummary(
            id: 'model-a',
            name: 'Model A',
            supportedReasoningEfforts: [
              CodexModelReasoningEffort(id: 'low', description: 'Fast'),
              CodexModelReasoningEffort(id: 'high', description: 'Deep'),
            ],
            defaultReasoningEffort: 'low',
          ),
          CodexModelSummary(
            id: 'model-b',
            name: 'Model B',
            supportedReasoningEfforts: [
              CodexModelReasoningEffort(id: 'medium', description: 'Balanced'),
              CodexModelReasoningEffort(id: 'xhigh', description: 'Maximum'),
            ],
            defaultReasoningEffort: 'medium',
          ),
        ],
      ),
    );
    final modelListController = ModelListController(
      readerProvider: () => modelReader,
    );
    addTearDown(modelListController.dispose);
    addTearDown(overrideController.dispose);

    await tester.pumpWidget(
      _ModelSheetHarness(
        overrideController: overrideController,
        modelListController: modelListController,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-chat-model-sheet')));
    await tester.pumpAndSettle();

    await _selectModel(tester, 'Model A');
    await tester.tap(
      find.byKey(const ValueKey('chat-model-command-effort-list')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('high').last);
    await tester.pumpAndSettle();

    await _selectModel(tester, 'Model B');
    expect(find.text('Server default (medium)'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('chat-model-command-effort-list')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('xhigh').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-model-command-apply')));
    await tester.pumpAndSettle();

    expect(find.text('turn / model-b / xhigh'), findsOneWidget);
  });

  testWidgets('keeps free text effort for models without capability metadata', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    final modelReader = _RecordingModelListReader(
      page: const ModelListPage(
        models: [CodexModelSummary(id: 'custom-model', name: 'Custom Model')],
      ),
    );
    final modelListController = ModelListController(
      readerProvider: () => modelReader,
    );
    addTearDown(modelListController.dispose);
    addTearDown(overrideController.dispose);

    await tester.pumpWidget(
      _ModelSheetHarness(
        overrideController: overrideController,
        modelListController: modelListController,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-chat-model-sheet')));
    await tester.pumpAndSettle();
    await _selectModel(tester, 'Custom Model');

    expect(
      find.byKey(const ValueKey('chat-model-command-effort')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-model-command-effort-list')),
      findsNothing,
    );
  });

  testWidgets('session scope uses existing session override values', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController()
      ..setSessionModelEffort(model: 'gpt-5.6-codex', effort: 'medium');
    addTearDown(overrideController.dispose);

    await tester.pumpWidget(
      _ModelSheetHarness(overrideController: overrideController),
    );

    await tester.tap(find.byKey(const ValueKey('open-chat-model-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('chat-model-command-model')),
          )
          .controller
          ?.text,
      'gpt-5.6-codex',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('chat-model-command-effort')),
          )
          .controller
          ?.text,
      'medium',
    );

    await tester.tap(find.byKey(const ValueKey('chat-model-command-apply')));
    await tester.pumpAndSettle();

    expect(find.text('session / gpt-5.6-codex / medium'), findsOneWidget);
  });
}

Future<void> _selectModel(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('chat-model-command-model-list')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

class _ModelSheetHarness extends StatefulWidget {
  const _ModelSheetHarness({
    required this.overrideController,
    this.modelListController,
  });

  final CodexConfigOverrideController overrideController;
  final ModelListController? modelListController;

  @override
  State<_ModelSheetHarness> createState() => _ModelSheetHarnessState();
}

class _ModelSheetHarnessState extends State<_ModelSheetHarness> {
  ChatModelOverrideResult? _result;

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
                    key: const ValueKey('open-chat-model-sheet'),
                    onPressed: () async {
                      final result =
                          await showModalBottomSheet<ChatModelOverrideResult>(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => ChatModelOverrideSheet(
                              controller: widget.overrideController,
                              modelListController: widget.modelListController,
                            ),
                          );
                      if (mounted) {
                        setState(() => _result = result);
                      }
                    },
                    child: const Text('Open'),
                  ),
                  Text(
                    _result == null
                        ? 'No result'
                        : '${_result!.scope.name} / '
                              '${_result!.model} / '
                              '${_result!.effort}',
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

class _RecordingModelListReader implements ModelListReader {
  _RecordingModelListReader({required this.page});

  final ModelListPage page;
  int calls = 0;

  @override
  Future<ModelListPage> listModels({
    String? cursor,
    int? limit,
    bool includeHidden = false,
  }) async {
    calls++;
    return page;
  }
}
