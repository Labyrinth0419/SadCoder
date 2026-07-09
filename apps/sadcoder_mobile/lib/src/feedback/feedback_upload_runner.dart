class FeedbackUploadResult {
  const FeedbackUploadResult({required this.threadId});

  factory FeedbackUploadResult.fromJson(Map<String, Object?> json) {
    return FeedbackUploadResult(threadId: json['threadId'] as String? ?? '');
  }

  final String threadId;
}

abstract interface class FeedbackUploadRunner {
  Future<FeedbackUploadResult> uploadFeedback({
    required String classification,
    String? reason,
    String? threadId,
    String? turnId,
    bool includeLogs = false,
  });
}
