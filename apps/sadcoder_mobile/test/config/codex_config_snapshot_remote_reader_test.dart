import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_snapshot_remote_reader.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';

void main() {
  test('combines config and managed requirements responses', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return switch (request.method) {
        'config/read' => {
          'config': {'model': 'gpt-5-codex'},
          'origins': const <String, Object?>{},
          'layers': const <Object?>[],
        },
        'configRequirements/read' => {
          'requirements': {
            'allowedApprovalPolicies': ['on-request'],
            'allowedSandboxModes': ['workspace-write'],
          },
        },
        'modelProvider/capabilities/read' => {
          'namespaceTools': true,
          'imageGeneration': false,
          'webSearch': true,
        },
        _ => <String, Object?>{},
      };
    });
    addTearDown(transport.close);
    final reader = CodexConfigSnapshotRemoteReader(
      CodexAppServerClient(transport),
    );

    final snapshot = await reader.readConfig(cwd: '/repo');

    expect(requests.map((request) => request.method), [
      'config/read',
      'configRequirements/read',
      'modelProvider/capabilities/read',
    ]);
    expect(requests[1].params, isNull);
    expect(requests.last.params, isEmpty);
    expect(snapshot.requirementsSupported, isTrue);
    expect(snapshot.requirements?['allowedApprovalPolicies'], ['on-request']);
    expect(snapshot.modelProviderCapabilitiesSupported, isTrue);
    expect(snapshot.modelProviderCapabilities?['namespaceTools'], isTrue);
    expect(snapshot.modelProviderCapabilities?['imageGeneration'], isFalse);
  });

  test('keeps config snapshots usable on older app-server versions', () async {
    final transport = MemoryJsonRpcTransport((request) {
      if (request.method == 'config/read') {
        return {
          'config': {'model': 'gpt-5-codex'},
          'origins': const <String, Object?>{},
          'layers': const <Object?>[],
        };
      }
      throw const JsonRpcRemoteException('Method not found', code: -32601);
    });
    addTearDown(transport.close);
    final reader = CodexConfigSnapshotRemoteReader(
      CodexAppServerClient(transport),
    );

    final snapshot = await reader.readConfig();

    expect(snapshot.displayValueFor('model'), 'gpt-5-codex');
    expect(snapshot.requirementsSupported, isFalse);
    expect(snapshot.requirements, isNull);
    expect(snapshot.modelProviderCapabilitiesSupported, isFalse);
    expect(snapshot.modelProviderCapabilities, isNull);
  });

  test('does not hide non-compatibility requirements failures', () async {
    final transport = MemoryJsonRpcTransport((request) {
      if (request.method == 'config/read') {
        return {
          'config': const <String, Object?>{},
          'origins': const <String, Object?>{},
          'layers': const <Object?>[],
        };
      }
      throw const JsonRpcRemoteException('Permission denied', code: -32603);
    });
    addTearDown(transport.close);
    final reader = CodexConfigSnapshotRemoteReader(
      CodexAppServerClient(transport),
    );

    await expectLater(
      reader.readConfig(),
      throwsA(
        isA<JsonRpcRemoteException>().having(
          (error) => error.code,
          'code',
          -32603,
        ),
      ),
    );
  });

  test(
    'does not hide non-compatibility provider capability failures',
    () async {
      final transport = MemoryJsonRpcTransport((request) {
        return switch (request.method) {
          'config/read' => {
            'config': const <String, Object?>{},
            'origins': const <String, Object?>{},
            'layers': const <Object?>[],
          },
          'configRequirements/read' => {'requirements': null},
          _ => throw const JsonRpcRemoteException(
            'Provider failed',
            code: -32603,
          ),
        };
      });
      addTearDown(transport.close);
      final reader = CodexConfigSnapshotRemoteReader(
        CodexAppServerClient(transport),
      );

      await expectLater(
        reader.readConfig(),
        throwsA(
          isA<JsonRpcRemoteException>().having(
            (error) => error.code,
            'code',
            -32603,
          ),
        ),
      );
    },
  );
}
