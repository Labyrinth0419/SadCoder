import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/background/background_connection_policy.dart';

void main() {
  test('background without active turn disconnects observation', () async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);

    expect(fixture.disconnects, 1);
    expect(fixture.connected.value, false);
    expect(fixture.keeper.retainContexts, isEmpty);
  });

  test('background with active turn retains the connection', () async {
    final fixture = _Fixture(activeTurnId: 'turn_1');
    addTearDown(fixture.dispose);

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);

    expect(fixture.disconnects, 0);
    expect(fixture.connected.value, true);
    expect(fixture.keeper.retainContexts.single.turnId, 'turn_1');

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.resumed);

    expect(fixture.keeper.retentions.single.released, true);
  });

  test('disabled active-turn retention disconnects in background', () async {
    final preferences = BackgroundConnectionPreferences(
      keepConnectionDuringActiveTurn: false,
    );
    final fixture = _Fixture(activeTurnId: 'turn_1', preferences: preferences);
    addTearDown(fixture.dispose);

    await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);

    expect(fixture.disconnects, 1);
    expect(fixture.keeper.retainContexts, isEmpty);
  });

  test(
    'active turn completion while backgrounded releases and disconnects',
    () async {
      final fixture = _Fixture(activeTurnId: 'turn_1');
      addTearDown(fixture.dispose);

      await fixture.coordinator.handleLifecycleState(AppLifecycleState.paused);
      fixture.turnId.value = null;
      await Future<void>.delayed(Duration.zero);

      expect(fixture.keeper.retentions.single.released, true);
      expect(fixture.disconnects, 1);
      expect(fixture.connected.value, false);
    },
  );
}

class _Fixture {
  _Fixture({String? activeTurnId, BackgroundConnectionPreferences? preferences})
    : preferences = preferences ?? BackgroundConnectionPreferences(),
      turnId = ValueNotifier<String?>(activeTurnId) {
    coordinator = AppLifecycleConnectionCoordinator(
      sessionListenable: connected,
      turnListenable: turnId,
      preferences: this.preferences,
      keeper: keeper,
      isConnected: () => connected.value,
      hasActiveTurn: () => turnId.value != null,
      endpointProvider: () => 'tester@localhost:22',
      activeThreadIdProvider: () => turnId.value == null ? null : 'thr_1',
      activeTurnIdProvider: () => turnId.value,
      disconnect: () async {
        disconnects++;
        connected.value = false;
      },
    )..start();
  }

  final ValueNotifier<bool> connected = ValueNotifier<bool>(true);
  final ValueNotifier<String?> turnId;
  final BackgroundConnectionPreferences preferences;
  final _RecordingKeeper keeper = _RecordingKeeper();
  late final AppLifecycleConnectionCoordinator coordinator;
  int disconnects = 0;

  Future<void> dispose() async {
    await coordinator.dispose();
    connected.dispose();
    turnId.dispose();
    preferences.dispose();
  }
}

class _RecordingKeeper implements BackgroundConnectionKeeper {
  final retainContexts = <BackgroundConnectionContext>[];
  final retentions = <_RecordingRetention>[];

  @override
  Future<BackgroundConnectionRetention> retain(
    BackgroundConnectionContext context,
  ) async {
    retainContexts.add(context);
    final retention = _RecordingRetention();
    retentions.add(retention);
    return retention;
  }
}

class _RecordingRetention implements BackgroundConnectionRetention {
  bool released = false;

  @override
  Future<void> release() async {
    released = true;
  }
}
