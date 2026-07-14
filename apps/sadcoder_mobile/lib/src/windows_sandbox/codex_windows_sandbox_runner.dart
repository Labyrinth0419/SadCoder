import '../protocol/codex_app_server_client.dart';
import 'windows_sandbox_runner.dart';

class CodexWindowsSandboxRunner implements WindowsSandboxRunner {
  const CodexWindowsSandboxRunner(this._client);

  final CodexAppServerClient _client;

  @override
  Future<WindowsSandboxReadiness> readReadiness() async {
    final response = await _client.readWindowsSandboxReadiness();
    return WindowsSandboxReadiness.fromWire(response['status']);
  }

  @override
  Future<WindowsSandboxSetupStart> startSetup({
    required WindowsSandboxSetupMode mode,
    String? cwd,
  }) async {
    final response = await _client.startWindowsSandboxSetup(
      mode: mode.wireName,
      cwd: cwd,
    );
    return WindowsSandboxSetupStart.fromJson(response);
  }
}
