import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/reviews/codex_thread_review_runner.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review.dart';
import 'package:sadcoder_mobile/src/reviews/thread_review_command.dart';

void main() {
  test('parseThreadReviewCommand defaults to current changes', () {
    final command = parseThreadReviewCommand('');

    expect(command?.delivery, isNull);
    expect(command?.target.kind, ThreadReviewTargetKind.uncommittedChanges);
    expect(command?.target.toJson(), {'type': 'uncommittedChanges'});
  });

  test('parseThreadReviewCommand parses delivery and target forms', () {
    final detachedCommit = parseThreadReviewCommand(
      'detached commit abc123 Polish colors',
    );
    final baseBranch = parseThreadReviewCommand('base main');
    final custom = parseThreadReviewCommand('focus on auth flow');

    expect(detachedCommit?.delivery, ThreadReviewDelivery.detached);
    expect(detachedCommit?.target.kind, ThreadReviewTargetKind.commit);
    expect(detachedCommit?.target.sha, 'abc123');
    expect(detachedCommit?.target.title, 'Polish colors');
    expect(baseBranch?.target.toJson(), {
      'type': 'baseBranch',
      'branch': 'main',
    });
    expect(custom?.target.toJson(), {
      'type': 'custom',
      'instructions': 'focus on auth flow',
    });
  });

  test('parseThreadReviewCommand rejects incomplete structured targets', () {
    expect(parseThreadReviewCommand('base'), isNull);
    expect(parseThreadReviewCommand('commit'), isNull);
    expect(parseThreadReviewCommand('--detached --bogus'), isNull);
  });

  test('ThreadReviewStartResult parses review start responses', () {
    final result = ThreadReviewStartResult.fromJson({
      'reviewThreadId': 'thr_1',
      'turn': {
        'id': 'turn_1',
        'status': 'inProgress',
        'itemsView': 'notLoaded',
        'items': <Object?>[],
      },
    });

    expect(result.reviewThreadId, 'thr_1');
    expect(result.turn.id, 'turn_1');
    expect(result.turn.status, 'inProgress');
  });

  test('CodexThreadReviewRunner calls review/start', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'reviewThreadId': 'thr_review',
        'turn': {
          'id': 'turn_review',
          'status': 'inProgress',
          'itemsView': 'notLoaded',
          'items': <Object?>[],
        },
      };
    });
    final runner = CodexThreadReviewRunner(CodexAppServerClient(transport));

    final result = await runner.startReview(
      threadId: 'thr_1',
      target: const ThreadReviewTarget.commit('abc123', title: 'Polish colors'),
      delivery: ThreadReviewDelivery.detached,
    );

    expect(result.reviewThreadId, 'thr_review');
    expect(result.turn.id, 'turn_review');
    expect(requests.single.method, 'review/start');
    expect(requests.single.params, {
      'threadId': 'thr_1',
      'target': {'type': 'commit', 'sha': 'abc123', 'title': 'Polish colors'},
      'delivery': 'detached',
    });
  });
}
