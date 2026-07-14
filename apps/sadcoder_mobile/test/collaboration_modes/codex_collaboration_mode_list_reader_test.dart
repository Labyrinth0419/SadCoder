import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/collaboration_modes/codex_collaboration_mode_list_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('reads the authoritative collaboration mode catalog', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'data': [
          {
            'name': 'Plan',
            'mode': 'plan',
            'model': null,
            'reasoning_effort': 'medium',
          },
          {'name': 'Default', 'mode': 'default'},
        ],
      };
    });
    addTearDown(transport.close);
    final reader = CodexCollaborationModeListReader(
      CodexAppServerClient(transport),
    );

    final catalog = await reader.listCollaborationModes();

    expect(requests.single.method, 'collaborationMode/list');
    expect(requests.single.params, isEmpty);
    expect(catalog.supported, isTrue);
    expect(catalog.presets, hasLength(2));
    expect(catalog.presetForMode('PLAN')?.reasoningEffort, 'medium');
    expect(catalog.presetForMode('plan')?.model, isNull);
  });

  test('reports unsupported only for method-not-found servers', () async {
    final transport = MemoryJsonRpcTransport((_) {
      throw const JsonRpcRemoteException('Method not found', code: -32601);
    });
    addTearDown(transport.close);
    final reader = CodexCollaborationModeListReader(
      CodexAppServerClient(transport),
    );

    final catalog = await reader.listCollaborationModes();

    expect(catalog.supported, isFalse);
    expect(catalog.presets, isEmpty);
  });

  test('does not hide non-compatibility catalog failures', () async {
    final transport = MemoryJsonRpcTransport((_) {
      throw const JsonRpcRemoteException('catalog failed', code: -32000);
    });
    addTearDown(transport.close);
    final reader = CodexCollaborationModeListReader(
      CodexAppServerClient(transport),
    );

    expect(
      reader.listCollaborationModes,
      throwsA(
        isA<JsonRpcRemoteException>().having(
          (error) => error.code,
          'code',
          -32000,
        ),
      ),
    );
  });
}
