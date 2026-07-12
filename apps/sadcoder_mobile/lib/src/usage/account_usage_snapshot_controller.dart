import 'package:flutter/foundation.dart';

import 'account_usage_snapshot_reader.dart';

typedef AccountUsageSnapshotReaderProvider =
    AccountUsageSnapshotReader? Function();

enum AccountUsageSnapshotStatus { idle, loading, loaded, failed }

class AccountUsageSnapshotController extends ChangeNotifier {
  AccountUsageSnapshotController({
    required AccountUsageSnapshotReaderProvider readerProvider,
  }) : _readerProvider = readerProvider;

  final AccountUsageSnapshotReaderProvider _readerProvider;
  AccountUsageSnapshotStatus _status = AccountUsageSnapshotStatus.idle;
  AccountUsageSnapshot? _snapshot;
  Object? _error;
  int _generation = 0;

  AccountUsageSnapshotStatus get status => _status;
  AccountUsageSnapshot? get snapshot => _snapshot;
  Object? get error => _error;

  void ingestRateLimitsUpdated(Map<String, Object?> payload) {
    final update = AccountRateLimitsSnapshot.fromJson(
      payload['rateLimits'] ?? payload['rate_limits'],
    );
    if (update == null) {
      return;
    }

    final current = _snapshot;
    final mergedRateLimits = current?.rateLimits?.mergeSparse(update) ?? update;
    final rateLimitsByLimitId = <String, AccountRateLimitsSnapshot>{
      ...?current?.rateLimitsByLimitId,
    };
    final limitId = mergedRateLimits.limitId;
    if (limitId != null) {
      final previous = rateLimitsByLimitId[limitId];
      rateLimitsByLimitId[limitId] =
          previous?.mergeSparse(mergedRateLimits) ?? mergedRateLimits;
    }

    _generation++;
    _snapshot = current == null
        ? AccountUsageSnapshot(
            summary: const AccountTokenUsageSummary(),
            dailyUsageBuckets: const [],
            rateLimits: mergedRateLimits,
            rateLimitsByLimitId: Map.unmodifiable(rateLimitsByLimitId),
            rateLimitResetCredits: null,
          )
        : current.copyWith(
            rateLimits: mergedRateLimits,
            rateLimitsByLimitId: Map.unmodifiable(rateLimitsByLimitId),
          );
    _setState(status: AccountUsageSnapshotStatus.loaded, error: null);
  }

  Future<void> refresh() async {
    final reader = _readerProvider();
    if (reader == null) {
      _generation++;
      _setState(status: AccountUsageSnapshotStatus.idle, error: null);
      return;
    }

    final generation = ++_generation;
    _setState(status: AccountUsageSnapshotStatus.loading, error: null);
    try {
      final snapshot = await reader.readUsage();
      if (generation != _generation) {
        return;
      }
      _snapshot = snapshot;
      _setState(status: AccountUsageSnapshotStatus.loaded, error: null);
    } on Object catch (error) {
      if (generation != _generation) {
        return;
      }
      _setState(status: AccountUsageSnapshotStatus.failed, error: error);
    }
  }

  void _setState({required AccountUsageSnapshotStatus status, Object? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }
}
