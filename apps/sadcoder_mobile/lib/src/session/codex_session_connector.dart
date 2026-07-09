import '../approvals/approval_state_controller.dart';
import '../protocol/codex_app_session.dart';
import '../ssh/ssh_profile.dart';
import '../ssh/ssh_proxy_connector.dart';
import '../threads/codex_thread_list_reader.dart';
import '../threads/thread_list_reader.dart';

abstract interface class CodexSessionConnectionHandle {
  SshProfile get profile;

  ThreadListReader get threadListReader;

  Future<void> get done;

  Future<void> close({bool notifyApprovalController = true});
}

abstract interface class CodexSessionConnectionStarter {
  Future<CodexSessionConnectionHandle> connect(
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
        threadListReader: CodexThreadListReader(session.client),
      );
    } catch (_) {
      await session?.close();
      await proxyConnection.close();
      rethrow;
    }
  }
}

class CodexSessionConnection implements CodexSessionConnectionHandle {
  CodexSessionConnection({
    required this.profile,
    required this.session,
    required this.threadListReader,
    required AgentProxyConnection proxyConnection,
  }) : _proxyConnection = proxyConnection,
       done = proxyConnection.done;

  @override
  final SshProfile profile;
  @override
  final Future<void> done;
  @override
  final ThreadListReader threadListReader;
  final CodexAppSession session;
  final AgentProxyConnection _proxyConnection;
  bool _closed = false;

  @override
  Future<void> close({bool notifyApprovalController = true}) async {
    if (_closed) {
      return;
    }
    _closed = true;
    await session.close(notifyApprovalController: notifyApprovalController);
    await _proxyConnection.close();
  }
}
