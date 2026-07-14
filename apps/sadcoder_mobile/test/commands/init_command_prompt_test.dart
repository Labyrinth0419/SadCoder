import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/commands/init_command_prompt.dart';

void main() {
  test('keeps /init prompt synchronized with checked-out Codex TUI', () {
    final upstream = File(
      '../../refs/codex/codex-rs/tui/prompt_for_init_command.md',
    ).readAsStringSync();

    expect(
      codexInitCommandPrompt.replaceAll('\r\n', '\n'),
      upstream.replaceAll('\r\n', '\n'),
    );
  });
}
