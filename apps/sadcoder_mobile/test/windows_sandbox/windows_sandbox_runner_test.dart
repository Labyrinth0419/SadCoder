import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/windows_sandbox/codex_windows_sandbox_runner.dart';
import 'package:sadcoder_mobile/src/windows_sandbox/windows_sandbox_runner.dart';

void main() {
  test(
    'reads readiness and starts elevated setup through app-server',
    () async {
      final requests = <JsonRpcRequest>[];
      final runner = CodexWindowsSandboxRunner(
        CodexAppServerClient(
          MemoryJsonRpcTransport((request) {
            requests.add(request);
            return switch (request.method) {
              'windowsSandbox/readiness' => {'status': 'updateRequired'},
              'windowsSandbox/setupStart' => {'started': true},
              _ => <String, Object?>{},
            };
          }),
        ),
      );

      final readiness = await runner.readReadiness();
      final started = await runner.startSetup(
        mode: WindowsSandboxSetupMode.elevated,
        cwd: r' C:\repo ',
      );

      expect(readiness, WindowsSandboxReadiness.updateRequired);
      expect(started.started, isTrue);
      expect(requests.map((request) => request.method), [
        'windowsSandbox/readiness',
        'windowsSandbox/setupStart',
      ]);
      expect(requests.first.params, isNull);
      expect(requests.last.params, {'mode': 'elevated', 'cwd': r'C:\repo'});
    },
  );

  test('parses known and forward-compatible wire values', () {
    expect(
      WindowsSandboxSetupMode.fromWire('unelevated'),
      WindowsSandboxSetupMode.unelevated,
    );
    expect(WindowsSandboxSetupMode.fromWire('future'), isNull);
    expect(
      WindowsSandboxReadiness.fromWire('notConfigured'),
      WindowsSandboxReadiness.notConfigured,
    );
    expect(
      WindowsSandboxReadiness.fromWire('future'),
      WindowsSandboxReadiness.unknown,
    );
  });
}
