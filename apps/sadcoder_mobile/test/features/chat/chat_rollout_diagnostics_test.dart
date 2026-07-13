import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_rollout_diagnostics.dart';

void main() {
  group('rolloutPathFromThreadRaw', () {
    test('reads canonical and snake case rollout path keys', () {
      expect(
        rolloutPathFromThreadRaw({'rolloutPath': '/tmp/rollout.jsonl'}),
        '/tmp/rollout.jsonl',
      );
      expect(
        rolloutPathFromThreadRaw({'rollout_path': '/tmp/snake.jsonl'}),
        '/tmp/snake.jsonl',
      );
      expect(
        rolloutPathFromThreadRaw({'currentRolloutPath': '/tmp/current.jsonl'}),
        '/tmp/current.jsonl',
      );
      expect(
        rolloutPathFromThreadRaw({
          'current_rollout_path': '/tmp/current-snake.jsonl',
        }),
        '/tmp/current-snake.jsonl',
      );
    });

    test('reads nested rollout path values', () {
      expect(
        rolloutPathFromThreadRaw({
          'rollout': {'path': '/tmp/nested.jsonl'},
        }),
        '/tmp/nested.jsonl',
      );
      expect(
        rolloutPathFromThreadRaw({
          'rollout': {
            'path': {'path': '/tmp/deep.jsonl'},
          },
        }),
        '/tmp/deep.jsonl',
      );
    });

    test('trims strings and skips empty values', () {
      expect(
        rolloutPathFromThreadRaw({'rolloutPath': '  /tmp/trimmed.jsonl  '}),
        '/tmp/trimmed.jsonl',
      );
      expect(
        rolloutPathFromThreadRaw({
          'rolloutPath': '  ',
          'rollout_path': '/tmp/fallback.jsonl',
        }),
        '/tmp/fallback.jsonl',
      );
    });

    test('returns the first non-empty path using stable key precedence', () {
      expect(
        rolloutPathFromThreadRaw({
          'rollout_path': '/tmp/snake.jsonl',
          'currentRolloutPath': '/tmp/current.jsonl',
          'rolloutPath': '/tmp/canonical.jsonl',
        }),
        '/tmp/canonical.jsonl',
      );
    });

    test('ignores unsupported values', () {
      expect(
        rolloutPathFromThreadRaw({
          'rolloutPath': 42,
          'rollout': {'path': ''},
        }),
        isNull,
      );
      expect(rolloutPathFromThreadRaw(const {}), isNull);
    });
  });
}
