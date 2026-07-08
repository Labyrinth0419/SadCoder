import '../approvals/approval_state_controller.dart';
import '../protocol/codex_app_session.dart';
import '../ssh/ssh_profile.dart';
import '../ssh/ssh_proxy_connector.dart';

abstract interface class CodexSessionConnectionStarter {
  Future<CodexSessionConnection> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  });
}

class CodexSessionConnector implements CodexSessionConnectionStarter {
  const CodexSessionConnector({
    required AgentProxyConnector proxyConnector,
    this.clientName = 'sadcoder-mobile',
    this.experimentalApi = true,
  }) : _proxyConnector = proxyConnector;

  final AgentProxyConnector _proxyConnector;
  final String clientName;
  final bool experimentalApi;

  @override
  Future<CodexSessionConnection> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    final proxyConnection = await _proxyConnector.connect(profile);
    CodexAppSession? session;
    try {
      session = CodexAppSession(
        proxyConnection.asJsonRpcTransport(),
        approvalController: approvalController,
      );
      await session.initialize(
        clientName: clientName,
        experimentalApi: experimentalApi,
      );
      return CodexSessionConnection(
        profile: profile,
        session: session,
        proxyConnection: proxyConnection,
      );
    } catch (_) {
      await session?.close();
      await proxyConnection.close();
      rethrow;
    }
  }
}

class CodexSessionConnection {
  CodexSessionConnection({
    required this.profile,
    required this.session,
    required AgentProxyConnection proxyConnection,
  }) : _proxyConnection = proxyConnection;

  final SshProfile profile;
  final CodexAppSession session;
  final AgentProxyConnection _proxyConnection;
  bool _closed = false;

  Future<void> close({bool notifyApprovalController = true}) async {
    if (_closed) {
      return;
    }
    _closed = true;
    await session.close(notifyApprovalController: notifyApprovalController);
    await _proxyConnection.close();
  }
}
