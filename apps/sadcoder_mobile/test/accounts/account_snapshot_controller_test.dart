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
