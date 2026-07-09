import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_override_controller.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_status_summary.dart';
import 'package:sadcoder_mobile/src/i18n/app_localizations.dart';

void main() {
  test('buildChatStatusSummary reports disconnected config sources', () {
    final l10n = AppLocalizations(const Locale('en'));
    final overrides = CodexConfigOverrideController(
      initialLayers: const CodexConfigOverrideLayers(
        appDefault: CodexConfigOverrides(model: 'gpt-5'),
        session: CodexConfigOverrides(cwd: '/repo'),
      ),
    );
    addTearDown(overrides.dispose);

    expect(
      buildChatStatusSummary(l10n: l10n, configOverrideController: overrides),
      'Connection status: Disconnected\n'
      'Model: gpt-5 / app default\n'
      'Reasoning effort: server default\n'
      'Approval policy: server default\n'
      'Sandbox mode: server default\n'
      'Working directory: /repo / session override\n'
      'Personality: server default',
    );
  });
}
