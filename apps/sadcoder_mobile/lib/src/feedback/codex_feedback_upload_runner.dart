import '../protocol/codex_app_server_client.dart';
import 'feedback_upload_runner.dart';

class CodexFeedbackUploadRunner implements FeedbackUploadRunner {
  const CodexFeedbackUploadRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<FeedbackUploadResult> uploadFeedback({
    required String classification,
    String? reason,
    String? threadId,
    String? turnId,
    bool includeLogs = false,
  }) async {
    final response = await _client.uploadFeedback(
      classification: classification,
      reason: reason,
      threadId: threadId,
      turnId: turnId,
      includeLogs: includeLogs,
    );
    return FeedbackUploadResult.fromJson(response);
  }
}
