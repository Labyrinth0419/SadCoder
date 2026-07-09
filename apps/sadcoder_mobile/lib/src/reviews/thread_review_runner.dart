import 'thread_review.dart';

abstract interface class ThreadReviewRunner {
  Future<ThreadReviewStartResult> startReview({
    required String threadId,
    required ThreadReviewTarget target,
    ThreadReviewDelivery? delivery,
  });
}
