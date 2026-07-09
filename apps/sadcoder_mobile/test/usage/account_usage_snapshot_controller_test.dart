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
