import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_controller.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';

void main() {
  test('refresh loads account snapshot from the current reader', () async {
    final reader = _FakeAccountSnapshotReader(
      snapshot: const AccountSnapshot(
        account: AccountSummary(type: 'apiKey'),
        requiresOpenaiAuth: true,
      ),
    );
    final controller = AccountSnapshotController(readerProvider: () => reader);
    addTearDown(controller.dispose);
    final statuses = <AccountSnapshotStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.refresh(refreshToken: true);

    expect(reader.refreshTokenValues, [true]);
    expect(controller.status, AccountSnapshotStatus.loaded);
    expect(controller.snapshot?.account?.type, 'apiKey');
    expect(statuses, [
      AccountSnapshotStatus.loading,
      AccountSnapshotStatus.loaded,
    ]);
  });

  test(
    'refresh without a reader returns to idle without clearing cache',
    () async {
      _FakeAccountSnapshotReader? reader = _FakeAccountSnapshotReader(
        snapshot: const AccountSnapshot(
          account: AccountSummary(type: 'chatgpt'),
          requiresOpenaiAuth: true,
        ),
      );
      final controller = AccountSnapshotController(
        readerProvider: () => reader,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      reader = null;
      await controller.refresh();

      expect(controller.status, AccountSnapshotStatus.idle);
      expect(controller.snapshot?.account?.type, 'chatgpt');
    },
  );

  test('refresh records failures', () async {
    final controller = AccountSnapshotController(
      readerProvider: () => _FailingAccountSnapshotReader(),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.status, AccountSnapshotStatus.failed);
    expect(controller.error, isA<StateError>());
  });

  test('account update preserves existing sparse account fields', () async {
    final reader = _FakeAccountSnapshotReader(
      snapshot: const AccountSnapshot(
        account: AccountSummary(
          type: 'chatgpt',
          email: 'user@example.com',
          planType: 'plus',
        ),
        requiresOpenaiAuth: true,
      ),
    );
    final controller = AccountSnapshotController(readerProvider: () => reader);
    addTearDown(controller.dispose);

    await controller.refresh();
    controller.ingestAccountUpdated({'authMode': null, 'planType': 'pro'});

    expect(controller.status, AccountSnapshotStatus.loaded);
    expect(controller.snapshot?.requiresOpenaiAuth, true);
    expect(controller.snapshot?.account?.type, 'chatgpt');
    expect(controller.snapshot?.account?.email, 'user@example.com');
    expect(controller.snapshot?.account?.planType, 'pro');
  });

  test('account update normalizes auth modes into account types', () async {
    final reader = _FakeAccountSnapshotReader(
      snapshot: const AccountSnapshot(
        account: AccountSummary(
          type: 'chatgpt',
          email: 'user@example.com',
          planType: 'plus',
        ),
        requiresOpenaiAuth: true,
      ),
    );
    final controller = AccountSnapshotController(readerProvider: () => reader);
    addTearDown(controller.dispose);

    await controller.refresh();
    controller.ingestAccountUpdated({'authMode': 'apikey'});

    expect(controller.snapshot?.requiresOpenaiAuth, true);
    expect(controller.snapshot?.account?.type, 'apiKey');
    expect(controller.snapshot?.account?.label, 'API key');
    expect(controller.snapshot?.account?.email, 'user@example.com');
    expect(controller.snapshot?.account?.planType, 'plus');
  });

  test('account update creates a minimal loaded snapshot', () {
    final controller = AccountSnapshotController(readerProvider: () => null);
    addTearDown(controller.dispose);

    controller.ingestAccountUpdated({
      'authMode': 'chatgpt',
      'planType': 'team',
    });

    expect(controller.status, AccountSnapshotStatus.loaded);
    expect(controller.snapshot?.requiresOpenaiAuth, false);
    expect(controller.snapshot?.account?.type, 'chatgpt');
    expect(controller.snapshot?.account?.planType, 'team');
  });

  test('empty account update does not notify', () {
    final controller = AccountSnapshotController(readerProvider: () => null);
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.ingestAccountUpdated(<String, Object?>{});
    controller.ingestAccountUpdated({'authMode': null, 'planType': null});

    expect(notifications, 0);
    expect(controller.status, AccountSnapshotStatus.idle);
    expect(controller.snapshot, isNull);
  });
}

class _FakeAccountSnapshotReader implements AccountSnapshotReader {
  _FakeAccountSnapshotReader({required this.snapshot});

  final AccountSnapshot snapshot;
  final refreshTokenValues = <bool>[];

  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) async {
    refreshTokenValues.add(refreshToken);
    return snapshot;
  }
}

class _FailingAccountSnapshotReader implements AccountSnapshotReader {
  @override
  Future<AccountSnapshot> readAccount({bool refreshToken = false}) {
    throw StateError('account read failed');
  }
}
