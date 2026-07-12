import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/approvals/approval_state_controller.dart';
import 'package:sadcoder_mobile/src/events/codex_event.dart';
import 'package:sadcoder_mobile/src/session/codex_session_connector.dart';
import 'package:sadcoder_mobile/src/session/codex_session_state_controller.dart';
import 'package:sadcoder_mobile/src/session/host_session_manager.dart';
import 'package:sadcoder_mobile/src/ssh/ssh_profile.dart';

void main() {
  test(
    'connects multiple host sessions without closing the previous one',
    () async {
      final starter = _RecordingSessionStarter();
      final manager = _manager(starter);
      addTearDown(manager.dispose);

      await manager.connect(_profileA);
      final firstSession = manager.sessionFor(_profileA.id)!;

      await manager.connect(_profileB);
      final secondSession = manager.sessionFor(_profileB.id)!;

      expect(starter.connectedProfiles, [_profileA, _profileB]);
      expect(manager.sessions.map((entry) => entry.profileId), [
        _profileA.id,
        _profileB.id,
      ]);
      expect(manager.activeProfileId, _profileB.id);
      expect(manager.activeSession, same(secondSession));
      expect(firstSession.status, CodexSessionStatus.connected);
      expect(secondSession.status, CodexSessionStatus.connected);
      expect(starter.connections.first.closeCount, 0);
    },
  );

  test('selects an existing host session without reconnecting', () async {
    final starter = _RecordingSessionStarter();
    final manager = _manager(starter);
    addTearDown(manager.dispose);

    await manager.connect(_profileA);
    await manager.connect(_profileB);

    expect(manager.select(_profileA.id), true);

    expect(manager.activeProfileId, _profileA.id);
    expect(starter.connectedProfiles, [_profileA, _profileB]);
  });

  test('connectOrSelect reuses a connected host session', () async {
    final starter = _RecordingSessionStarter();
    final manager = _manager(starter);
    addTearDown(manager.dispose);

    await manager.connect(_profileA);
    await manager.connect(_profileB);

    final controller = await manager.connectOrSelect(_profileA);

    expect(
      controller,
      same(manager.sessionFor(_profileA.id)!.sessionController),
    );
    expect(manager.activeProfileId, _profileA.id);
    expect(starter.connectedProfiles, [_profileA, _profileB]);
    expect(starter.connections.first.closeCount, 0);
  });

  test('coalesces concurrent connect calls for the same host', () async {
    final starter = _DeferredSessionStarter();
    final manager = _manager(starter);
    addTearDown(manager.dispose);

    final first = manager.connect(_profileA);
    final second = manager.connect(_profileA);

    expect(second, same(first));
    expect(starter.connectedProfiles, [_profileA]);
    expect(
      manager.sessionFor(_profileA.id)!.status,
      CodexSessionStatus.connecting,
    );

    starter.completeNext();
    final controllers = await Future.wait([first, second]);

    expect(controllers[1], same(controllers[0]));
    expect(starter.connections, hasLength(1));
    expect(controllers[0].status, CodexSessionStatus.connected);
  });

  test('connectOrSelect reuses a pending host connect', () async {
    final starter = _DeferredSessionStarter();
    final manager = _manager(starter);
    addTearDown(manager.dispose);

    final first = manager.connect(_profileA);
    final second = manager.connectOrSelect(_profileA);

    expect(second, same(first));
    expect(starter.connectedProfiles, [_profileA]);
    expect(manager.activeProfileId, _profileA.id);

    starter.completeNext();
    expect(await second, same(await first));
    expect(starter.connections, hasLength(1));
  });

  test('clears pending host connect after failure', () async {
    final starter = _DeferredSessionStarter();
    final manager = _manager(starter);
    addTearDown(manager.dispose);

    final failed = manager.connect(_profileA);
    starter.failNext(StateError('boom'));

    await expectLater(failed, throwsA(isA<StateError>()));
    expect(manager.sessionFor(_profileA.id)!.status, CodexSessionStatus.failed);

    final retried = manager.connect(_profileA);
    expect(starter.connectedProfiles, [_profileA, _profileA]);

    starter.completeNext();
    final controller = await retried;

    expect(controller.status, CodexSessionStatus.connected);
    expect(starter.connections, hasLength(2));
  });

  test('disconnect releases pending host connect reuse', () async {
    final starter = _DeferredSessionStarter();
    final manager = _manager(starter);
    addTearDown(manager.dispose);

    final first = manager.connect(_profileA);
    expect(await manager.disconnect(_profileA.id), true);
    final second = manager.connect(_profileA);

    expect(first, isNot(same(second)));
    expect(starter.connectedProfiles, [_profileA, _profileA]);

    starter.completeNext();
    starter.completeNext();
    await first;
    final controller = await second;

    expect(starter.connections.first.closeCount, 1);
    expect(controller.status, CodexSessionStatus.connected);
  });

  test('disconnects one host session without affecting another', () async {
    final starter = _RecordingSessionStarter();
    final manager = _manager(starter);
    addTearDown(manager.dispose);

    await manager.connect(_profileA);
    await manager.connect(_profileB);

    expect(await manager.disconnect(_profileA.id), true);

    expect(manager.sessionFor(_profileA.id)!.status, CodexSessionStatus.idle);
    expect(
      manager.sessionFor(_profileB.id)!.status,
      CodexSessionStatus.connected,
    );
    expect(starter.connections[0].closeCount, 1);
    expect(starter.connections[1].closeCount, 0);
  });

  test('uses endpoint id for manual profiles', () {
    const profile = SshProfile(
      id: 'manual',
      name: 'Manual',
      host: 'Example.COM',
      username: 'Alice',
      port: 2200,
    );

    expect(hostSessionProfileId(profile), 'alice@example.com:2200');
  });
}

HostSessionManager _manager(CodexSessionConnectionStarter starter) {
  return HostSessionManager(
    controllerFactory: (approvalController) => CodexSessionStateController(
      connector: starter,
      approvalController: approvalController,
    ),
  );
}

const _profileA = SshProfile(
  id: 'alice@srv-a.dev:22',
  name: 'Server A',
  host: 'srv-a.dev',
  username: 'alice',
);

const _profileB = SshProfile(
  id: 'bob@srv-b.dev:22',
  name: 'Server B',
  host: 'srv-b.dev',
  username: 'bob',
);

class _RecordingSessionStarter implements CodexSessionConnectionStarter {
  final connectedProfiles = <SshProfile>[];
  final connections = <_FakeConnectionHandle>[];

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) async {
    connectedProfiles.add(profile);
    final connection = _FakeConnectionHandle(profile);
    connections.add(connection);
    return connection;
  }
}

class _DeferredSessionStarter implements CodexSessionConnectionStarter {
  final connectedProfiles = <SshProfile>[];
  final connections = <_FakeConnectionHandle>[];
  final _pendingConnections = <_PendingConnection>[];

  @override
  Future<CodexSessionConnectionHandle> connect(
    SshProfile profile, {
    ApprovalStateController? approvalController,
  }) {
    connectedProfiles.add(profile);
    final connection = _FakeConnectionHandle(profile);
    connections.add(connection);
    final pendingConnection = _PendingConnection(connection);
    _pendingConnections.add(pendingConnection);
    return pendingConnection.future;
  }

  void completeNext() {
    final pendingConnection = _pendingConnections.removeAt(0);
    pendingConnection.complete();
  }

  void failNext(Object error) {
    final pendingConnection = _pendingConnections.removeAt(0);
    pendingConnection.fail(error);
  }
}

class _PendingConnection {
  _PendingConnection(this.connection);

  final _FakeConnectionHandle connection;
  final Completer<CodexSessionConnectionHandle> _completer =
      Completer<CodexSessionConnectionHandle>();

  Future<CodexSessionConnectionHandle> get future => _completer.future;

  void complete() {
    _completer.complete(connection);
  }

  void fail(Object error) {
    _completer.completeError(error);
  }
}

class _FakeConnectionHandle extends Fake
    implements CodexSessionConnectionHandle {
  _FakeConnectionHandle(this.profile);

  final Completer<void> _done = Completer<void>();
  int closeCount = 0;

  @override
  final SshProfile profile;

  @override
  Stream<CodexEvent> get events => const Stream.empty();

  @override
  Future<void> get done => _done.future;

  @override
  Future<Map<String, Object?>> restartBackend() async {
    return {'reconnectRequired': true};
  }

  @override
  Future<Map<String, Object?>> requestRaw({
    required String method,
    Map<String, Object?>? params,
  }) async {
    final result = <String, Object?>{'method': method.trim()};
    if (params != null) {
      result['params'] = params;
    }
    return result;
  }

  @override
  Future<Map<String, Object?>> stopBackend() async {
    return {'stopped': true};
  }

  @override
  Future<void> close({bool notifyApprovalController = true}) async {
    closeCount++;
    if (!_done.isCompleted) {
      _done.complete();
    }
  }
}
