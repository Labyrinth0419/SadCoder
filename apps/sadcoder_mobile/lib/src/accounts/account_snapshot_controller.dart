import 'package:flutter/foundation.dart';

import 'account_snapshot_reader.dart';

typedef AccountSnapshotReaderProvider = AccountSnapshotReader? Function();

enum AccountSnapshotStatus { idle, loading, loaded, failed }

class AccountSnapshotController extends ChangeNotifier {
  AccountSnapshotController({
    required AccountSnapshotReaderProvider readerProvider,
  }) : _readerProvider = readerProvider;

  final AccountSnapshotReaderProvider _readerProvider;
  AccountSnapshotStatus _status = AccountSnapshotStatus.idle;
  AccountSnapshot? _snapshot;
  Object? _error;
  int _generation = 0;

  AccountSnapshotStatus get status => _status;
  AccountSnapshot? get snapshot => _snapshot;
  Object? get error => _error;

  void ingestAccountUpdated(Map<String, Object?> payload) {
    final authMode = _stringField(payload, ['authMode', 'auth_mode']);
    final planType = _stringField(payload, ['planType', 'plan_type']);
    if (authMode == null && planType == null) {
      return;
    }

    final current = _snapshot;
    final currentAccount = current?.account;
    final nextAccount = currentAccount == null
        ? AccountSummary.fromAccountUpdated(
            authMode: authMode,
            planType: planType,
          )
        : currentAccount.mergeAccountUpdated(
            authMode: authMode,
            planType: planType,
          );
    if (nextAccount == null) {
      return;
    }

    _generation++;
    _snapshot =
        current?.copyWith(account: nextAccount) ??
        AccountSnapshot(account: nextAccount, requiresOpenaiAuth: false);
    _setState(status: AccountSnapshotStatus.loaded, error: null);
  }

  Future<void> refresh({bool refreshToken = false}) async {
    final reader = _readerProvider();
    if (reader == null) {
      _generation++;
      _setState(status: AccountSnapshotStatus.idle, error: null);
      return;
    }

    final generation = ++_generation;
    _setState(status: AccountSnapshotStatus.loading, error: null);
    try {
      final snapshot = await reader.readAccount(refreshToken: refreshToken);
      if (generation != _generation) {
        return;
      }
      _snapshot = snapshot;
      _setState(status: AccountSnapshotStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: AccountSnapshotStatus.failed, error: error);
    }
  }

  void _setState({required AccountSnapshotStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}

String? _stringField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}
