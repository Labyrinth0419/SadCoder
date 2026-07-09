import '../protocol/codex_app_server_client.dart';
import 'thread_review.dart';
import 'thread_review_runner.dart';

class CodexThreadReviewRunner implements ThreadReviewRunner {
  const CodexThreadReviewRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<ThreadReviewStartResult> startReview({
    required String threadId,
    required ThreadReviewTarget target,
    ThreadReviewDelivery? delivery,
  }) async {
    final response = await _client.startReview(
      threadId: threadId,
      target: target.toJson(),
      delivery: delivery?.wireName,
    );
    return ThreadReviewStartResult.fromJson(response);
  }
}
