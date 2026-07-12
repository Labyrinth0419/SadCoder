import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/usage/account_usage_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/usage/account_usage_snapshot_reader.dart';

void main() {
  test('refresh loads usage from the current reader', () async {
    final reader = _FakeAccountUsageSnapshotReader(
      snapshot: const AccountUsageSnapshot(
        summary: AccountTokenUsageSummary(lifetimeTokens: 1234),
        dailyUsageBuckets: [],
        rateLimits: null,
        rateLimitsByLimitId: {},
        rateLimitResetCredits: null,
      ),
    );
    final controller = AccountUsageSnapshotController(
      readerProvider: () => reader,
    );
    addTearDown(controller.dispose);
    final statuses = <AccountUsageSnapshotStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.refresh();

    expect(reader.calls, 1);
    expect(controller.status, AccountUsageSnapshotStatus.loaded);
    expect(controller.snapshot?.summary.lifetimeTokens, 1234);
    expect(statuses, [
      AccountUsageSnapshotStatus.loading,
      AccountUsageSnapshotStatus.loaded,
    ]);
  });

  test(
    'refresh without a reader returns to idle without clearing cache',
    () async {
      _FakeAccountUsageSnapshotReader? reader = _FakeAccountUsageSnapshotReader(
        snapshot: const AccountUsageSnapshot(
          summary: AccountTokenUsageSummary(lifetimeTokens: 1234),
          dailyUsageBuckets: [],
          rateLimits: null,
          rateLimitsByLimitId: {},
          rateLimitResetCredits: null,
        ),
      );
      final controller = AccountUsageSnapshotController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      reader = null;
      await controller.refresh();

      expect(controller.status, AccountUsageSnapshotStatus.idle);
      expect(controller.snapshot?.summary.lifetimeTokens, 1234);
    },
  );

  test('refresh records failures', () async {
    final controller = AccountUsageSnapshotController(
      readerProvider: () => _FailingAccountUsageSnapshotReader(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.status, AccountUsageSnapshotStatus.failed);
    expect(controller.error, isA<StateError>());
  });

  test('rate-limit updates merge into the loaded usage snapshot', () async {
    final reader = _FakeAccountUsageSnapshotReader(
      snapshot: const AccountUsageSnapshot(
        summary: AccountTokenUsageSummary(lifetimeTokens: 1234),
        dailyUsageBuckets: [],
        rateLimits: AccountRateLimitsSnapshot(
          limitId: 'codex',
          limitName: 'Codex Pro',
          primary: AccountRateLimitWindow(
            usedPercent: 20,
            windowDurationMins: 15,
            resetsAt: 1784246400,
          ),
          planType: 'pro',
        ),
        rateLimitsByLimitId: {
          'codex': AccountRateLimitsSnapshot(
            limitId: 'codex',
            limitName: 'Codex Pro',
            primary: AccountRateLimitWindow(
              usedPercent: 20,
              windowDurationMins: 15,
              resetsAt: 1784246400,
            ),
            planType: 'pro',
          ),
        },
        rateLimitResetCredits: null,
      ),
    );
    final controller = AccountUsageSnapshotController(
      readerProvider: () => reader,
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    controller.ingestRateLimitsUpdated({
      'rateLimits': {
        'limitId': 'codex',
        'primary': {'usedPercent': 85},
        'limitName': null,
        'planType': null,
      },
    });

    final rateLimits = controller.snapshot!.rateLimits!;
    expect(controller.status, AccountUsageSnapshotStatus.loaded);
    expect(controller.error, isNull);
    expect(controller.snapshot?.summary.lifetimeTokens, 1234);
    expect(rateLimits.limitName, 'Codex Pro');
    expect(rateLimits.planType, 'pro');
    expect(rateLimits.primary?.usedPercent, 85);
    expect(rateLimits.primary?.windowDurationMins, 15);
    expect(rateLimits.primary?.resetsAt, 1784246400);
    expect(
      controller.snapshot!.rateLimitsByLimitId['codex']?.primary?.usedPercent,
      85,
    );
  });

  test('rate-limit update creates a minimal loaded snapshot', () {
    final controller = AccountUsageSnapshotController(
      readerProvider: () => null,
    );
    addTearDown(controller.dispose);

    controller.ingestRateLimitsUpdated({
      'rateLimits': {
        'limitId': 'codex',
        'primary': {'usedPercent': 45},
      },
    });

    expect(controller.status, AccountUsageSnapshotStatus.loaded);
    expect(controller.snapshot?.summary.hasData, isFalse);
    expect(controller.snapshot?.dailyUsageBuckets, isEmpty);
    expect(controller.snapshot?.rateLimits?.primary?.usedPercent, 45);
    expect(
      controller.snapshot!.rateLimitsByLimitId['codex']?.primary?.usedPercent,
      45,
    );
  });

  test('malformed rate-limit updates do not notify', () {
    final controller = AccountUsageSnapshotController(
      readerProvider: () => null,
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.ingestRateLimitsUpdated({'rateLimits': <String, Object?>{}});
    controller.ingestRateLimitsUpdated(<String, Object?>{});

    expect(notifications, 0);
    expect(controller.status, AccountUsageSnapshotStatus.idle);
    expect(controller.snapshot, isNull);
  });
}

class _FakeAccountUsageSnapshotReader implements AccountUsageSnapshotReader {
  _FakeAccountUsageSnapshotReader({required this.snapshot});

  final AccountUsageSnapshot snapshot;
  int calls = 0;

  @override
  Future<AccountUsageSnapshot> readUsage() async {
    calls++;
    return snapshot;
  }
}

class _FailingAccountUsageSnapshotReader implements AccountUsageSnapshotReader {
  @override
  Future<AccountUsageSnapshot> readUsage() {
    throw StateError('usage failed');
  }
}
