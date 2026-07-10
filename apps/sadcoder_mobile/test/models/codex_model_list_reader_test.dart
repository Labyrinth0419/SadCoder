import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/models/codex_model_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('listModels follows app-server pagination', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      final cursor = request.params?['cursor'];
      if (cursor == '2') {
        return {
          'data': [
            {'model': 'gpt-5.6-terra', 'displayName': 'GPT-5.6 Terra'},
          ],
          'nextCursor': null,
        };
      }
      return {
        'data': [
          {'model': 'gpt-5.6-sol', 'displayName': 'GPT-5.6 Sol'},
        ],
        'nextCursor': '2',
      };
    });
    final reader = CodexModelListReader(CodexAppServerClient(transport));

    final page = await reader.listModels(limit: 1, includeHidden: true);

    expect(page.models.map((model) => model.id), [
      'gpt-5.6-sol',
      'gpt-5.6-terra',
    ]);
    expect(requests.map((request) => request.params), [
      {'limit': 1, 'includeHidden': true},
      {'cursor': '2', 'limit': 1, 'includeHidden': true},
    ]);
  });

  test('listModels rejects repeated pagination cursors', () async {
    final transport = MemoryJsonRpcTransport((request) {
      return {
        'data': [
          {'model': 'gpt-5.6-sol'},
        ],
        'nextCursor': 'same',
      };
    });
    final reader = CodexModelListReader(CodexAppServerClient(transport));

    await expectLater(
      reader.listModels(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'model/list returned a repeated cursor',
        ),
      ),
    );
  });
}
