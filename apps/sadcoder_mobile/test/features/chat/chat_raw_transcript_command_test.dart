import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_raw_transcript_command.dart';

void main() {
  test('raw transcript command toggles for empty or toggle arguments', () {
    expect(
      rawTranscriptVisibilityForCommand(current: false, arguments: ''),
      isTrue,
    );
    expect(
      rawTranscriptVisibilityForCommand(current: true, arguments: ' toggle '),
      isFalse,
    );
  });

  test('raw transcript command enables raw view with on aliases', () {
    for (final argument in const ['on', 'true', '1', ' ON ']) {
      expect(
        rawTranscriptVisibilityForCommand(current: false, arguments: argument),
        isTrue,
      );
    }
  });

  test('raw transcript command disables raw view with off aliases', () {
    for (final argument in const ['off', 'false', '0', ' OFF ']) {
      expect(
        rawTranscriptVisibilityForCommand(current: true, arguments: argument),
        isFalse,
      );
    }
  });

  test('raw transcript command rejects unsupported arguments', () {
    expect(
      rawTranscriptVisibilityForCommand(current: false, arguments: 'sideways'),
      isNull,
    );
  });
}
