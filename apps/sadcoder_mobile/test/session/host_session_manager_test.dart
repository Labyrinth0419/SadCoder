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

HostSessionManager _manager(_RecordingSessionStarter starter) {
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
  Future<void> close({bool notifyApprovalController = true}) async {
    closeCount++;
    if (!_done.isCompleted) {
      _done.complete();
    }
  }
}
