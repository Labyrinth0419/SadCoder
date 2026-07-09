import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/feedback/codex_feedback_upload_runner.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('CodexFeedbackUploadRunner calls app-server feedback/upload', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {'threadId': 'feedback_thread'};
    });
    final runner = CodexFeedbackUploadRunner(CodexAppServerClient(transport));

    final result = await runner.uploadFeedback(
      classification: 'bug',
      reason: 'Something broke',
      threadId: 'thr_1',
      turnId: 'turn_1',
      includeLogs: true,
    );

    expect(result.threadId, 'feedback_thread');
    expect(requests.single.method, 'feedback/upload');
    expect(requests.single.params, {
      'classification': 'bug',
      'reason': 'Something broke',
      'threadId': 'thr_1',
      'includeLogs': true,
      'tags': {'turn_id': 'turn_1'},
    });
  });
}
