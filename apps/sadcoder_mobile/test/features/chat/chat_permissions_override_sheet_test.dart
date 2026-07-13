import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/appearance/app_appearance_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_permissions_override_sheet.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_controller.dart';
import 'package:sadcoder_mobile/src/permissions/permission_profile_list_reader.dart';
import 'package:sadcoder_mobile/src/theme/sadcoder_theme.dart';

void main() {
  testWidgets('returns high-risk sandbox and approval override', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController();
    addTearDown(overrideController.dispose);

    await tester.pumpWidget(
      _PermissionsSheetHarness(overrideController: overrideController),
    );

    await tester.tap(find.byKey(const ValueKey('open-chat-permissions-sheet')));
    await tester.pumpAndSettle();

    await _selectDropdownOption(
      tester,
      const ValueKey('chat-permissions-command-approval-policy'),
      'never',
    );
    await _selectDropdownOption(
      tester,
      const ValueKey('chat-permissions-command-sandbox-mode'),
      'dangerFullAccess',
    );

    expect(
      find.text(
        'High risk: these permissions can let Codex run with less review or broader filesystem access.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('chat-permissions-command-apply')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('turn / never / dangerFullAccess / false /  / true'),
      findsOneWidget,
    );
  });

  testWidgets('refreshes permission profiles with cwd and returns selection', (
    tester,
  ) async {
    final overrideController = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        session: CodexConfigOverrides(cwd: '/repo'),
      ),
    );
    final profileReader = _RecordingPermissionProfileListReader(
      page: const PermissionProfileListPage(
        profiles: [
          PermissionProfileSummary(
            id: ':workspace',
            description: 'Workspace write',
          ),
          PermissionProfileSummary(
            id: ':danger-full-access',
            description: 'Full access',
            allowed: false,
          ),
        ],
      ),
    );
    final profileController = PermissionProfileListController(
      readerProvider: () => profileReader,
    );
    addTearDown(profileController.dispose);
    addTearDown(overrideController.dispose);

    await tester.pumpWidget(
      _PermissionsSheetHarness(
        overrideController: overrideController,
        permissionProfileListController: profileController,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-chat-permissions-sheet')));
    await tester.pumpAndSettle();

    expect(profileReader.cwdValues, ['/repo']);

    await _selectDropdownOption(
      tester,
      const ValueKey('chat-permissions-command-sandbox-mode'),
      'workspaceWrite',
    );
    await tester.tap(
      find.byKey(const ValueKey('chat-permissions-command-network-access')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('chat-permissions-command-permission-profile')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(':workspace / Workspace write').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(
              const ValueKey('chat-permissions-command-network-access'),
            ),
          )
          .onChanged,
      isNull,
    );

    await tester.tap(
      find.byKey(const ValueKey('chat-permissions-command-apply')),
    );
    await tester.pumpAndSettle();

    expect(find.text('turn /  /  / null / :workspace / false'), findsOneWidget);
  });
}

class _PermissionsSheetHarness extends StatefulWidget {
  const _PermissionsSheetHarness({
    required this.overrideController,
    this.permissionProfileListController,
  });

  final CodexConfigOverrideController overrideController;
  final PermissionProfileListController? permissionProfileListController;

  @override
  State<_PermissionsSheetHarness> createState() =>
      _PermissionsSheetHarnessState();
}

class _PermissionsSheetHarnessState extends State<_PermissionsSheetHarness> {
  ChatPermissionsOverrideResult? _result;

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
                    key: const ValueKey('open-chat-permissions-sheet'),
                    onPressed: () async {
                      final result =
                          await showModalBottomSheet<
                            ChatPermissionsOverrideResult
                          >(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => ChatPermissionsOverrideSheet(
                              controller: widget.overrideController,
                              permissionProfileListController:
                                  widget.permissionProfileListController,
                            ),
                          );
                      if (mounted) {
                        setState(() => _result = result);
                      }
                    },
                    child: const Text('Open'),
                  ),
                  Text(_result == null ? 'No result' : _resultText(_result!)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _resultText(ChatPermissionsOverrideResult result) {
    final sandboxType = result.sandboxPolicy['type'] ?? '';
    final networkAccess = result.sandboxPolicy['networkAccess'];
    return '${result.scope.name} / '
        '${result.approvalPolicy} / '
        '$sandboxType / '
        '$networkAccess / '
        '${result.permissionProfile ?? ''} / '
        '${result.isHighRisk}';
  }
}

class _RecordingPermissionProfileListReader
    implements PermissionProfileListReader {
  _RecordingPermissionProfileListReader({required this.page});

  final PermissionProfileListPage page;
  final List<String?> cwdValues = [];

  @override
  Future<PermissionProfileListPage> listPermissionProfiles({
    String? cwd,
  }) async {
    cwdValues.add(cwd);
    return page;
  }
}

Future<void> _selectDropdownOption(
  WidgetTester tester,
  ValueKey<String> key,
  String option,
) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}
