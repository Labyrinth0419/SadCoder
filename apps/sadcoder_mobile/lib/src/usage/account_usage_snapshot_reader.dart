abstract interface class AccountUsageSnapshotReader {
  Future<AccountUsageSnapshot> readUsage();
}

class AccountUsageSnapshot {
  const AccountUsageSnapshot({
    required this.summary,
    required this.dailyUsageBuckets,
    required this.rateLimits,
    required this.rateLimitsByLimitId,
    required this.rateLimitResetCredits,
  });

  factory AccountUsageSnapshot.fromJson({
    required Map<String, Object?> usageJson,
    required Map<String, Object?> rateLimitsJson,
  }) {
    return AccountUsageSnapshot(
      summary: AccountTokenUsageSummary.fromJson(usageJson['summary']),
      dailyUsageBuckets: _dailyBuckets(
        _valueField(usageJson, ['dailyUsageBuckets', 'daily_usage_buckets']),
      ),
      rateLimits: AccountRateLimitsSnapshot.fromJson(
        _valueField(rateLimitsJson, ['rateLimits', 'rate_limits']),
      ),
      rateLimitsByLimitId: _rateLimitsByLimitId(
        _valueField(rateLimitsJson, [
          'rateLimitsByLimitId',
          'rate_limits_by_limit_id',
        ]),
      ),
      rateLimitResetCredits: AccountRateLimitResetCreditsSummary.fromJson(
        _valueField(rateLimitsJson, [
          'rateLimitResetCredits',
          'rate_limit_reset_credits',
        ]),
      ),
    );
  }

  final AccountTokenUsageSummary summary;
  final List<AccountTokenUsageDailyBucket> dailyUsageBuckets;
  final AccountRateLimitsSnapshot? rateLimits;
  final Map<String, AccountRateLimitsSnapshot> rateLimitsByLimitId;
  final AccountRateLimitResetCreditsSummary? rateLimitResetCredits;
}

class AccountTokenUsageSummary {
  const AccountTokenUsageSummary({
    this.lifetimeTokens,
    this.peakDailyTokens,
    this.longestRunningTurnSec,
    this.currentStreakDays,
    this.longestStreakDays,
  });

  factory AccountTokenUsageSummary.fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return const AccountTokenUsageSummary();
    }
    return AccountTokenUsageSummary(
      lifetimeTokens: _intField(map, ['lifetimeTokens', 'lifetime_tokens']),
      peakDailyTokens: _intField(map, ['peakDailyTokens', 'peak_daily_tokens']),
      longestRunningTurnSec: _intField(map, [
        'longestRunningTurnSec',
        'longest_running_turn_sec',
      ]),
      currentStreakDays: _intField(map, [
        'currentStreakDays',
        'current_streak_days',
      ]),
      longestStreakDays: _intField(map, [
        'longestStreakDays',
        'longest_streak_days',
      ]),
    );
  }

  final int? lifetimeTokens;
  final int? peakDailyTokens;
  final int? longestRunningTurnSec;
  final int? currentStreakDays;
  final int? longestStreakDays;

  bool get hasData =>
      lifetimeTokens != null ||
      peakDailyTokens != null ||
      longestRunningTurnSec != null ||
      currentStreakDays != null ||
      longestStreakDays != null;
}

class AccountTokenUsageDailyBucket {
  const AccountTokenUsageDailyBucket({
    required this.startDate,
    required this.tokens,
  });

  static AccountTokenUsageDailyBucket? fromJson(Object? value) {
    final map = _objectMap(value);
    final startDate = _stringField(map, ['startDate', 'start_date']);
    final tokens = _intValue(map['tokens']);
    if (startDate == null || tokens == null) {
      return null;
    }
    return AccountTokenUsageDailyBucket(startDate: startDate, tokens: tokens);
  }

  final String startDate;
  final int tokens;
}

class AccountRateLimitsSnapshot {
  const AccountRateLimitsSnapshot({
    this.limitId,
    this.limitName,
    this.primary,
    this.secondary,
    this.credits,
    this.individualLimit,
    this.planType,
    this.rateLimitReachedType,
  });

  static AccountRateLimitsSnapshot? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return null;
    }
    final snapshot = AccountRateLimitsSnapshot(
      limitId: _stringField(map, ['limitId', 'limit_id']),
      limitName: _stringField(map, ['limitName', 'limit_name']),
      primary: AccountRateLimitWindow.fromJson(map['primary']),
      secondary: AccountRateLimitWindow.fromJson(map['secondary']),
      credits: AccountCreditsSnapshot.fromJson(map['credits']),
      individualLimit: AccountSpendControlLimitSnapshot.fromJson(
        _valueField(map, ['individualLimit', 'individual_limit']),
      ),
      planType: _stringField(map, ['planType', 'plan_type']),
      rateLimitReachedType: _stringField(map, [
        'rateLimitReachedType',
        'rate_limit_reached_type',
      ]),
    );
    return snapshot.hasData ? snapshot : null;
  }

  final String? limitId;
  final String? limitName;
  final AccountRateLimitWindow? primary;
  final AccountRateLimitWindow? secondary;
  final AccountCreditsSnapshot? credits;
  final AccountSpendControlLimitSnapshot? individualLimit;
  final String? planType;
  final String? rateLimitReachedType;

  bool get hasData =>
      _hasText(limitId) ||
      _hasText(limitName) ||
      primary != null ||
      secondary != null ||
      credits != null ||
      individualLimit != null ||
      _hasText(planType) ||
      _hasText(rateLimitReachedType);
}

class AccountRateLimitWindow {
  const AccountRateLimitWindow({
    this.usedPercent,
    this.windowDurationMins,
    this.resetsAt,
  });

  static AccountRateLimitWindow? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return null;
    }
    final window = AccountRateLimitWindow(
      usedPercent: _intField(map, ['usedPercent', 'used_percent']),
      windowDurationMins: _intField(map, [
        'windowDurationMins',
        'window_duration_mins',
      ]),
      resetsAt: _intField(map, ['resetsAt', 'resets_at']),
    );
    return window.hasData ? window : null;
  }

  final int? usedPercent;
  final int? windowDurationMins;
  final int? resetsAt;

  bool get hasData =>
      usedPercent != null || windowDurationMins != null || resetsAt != null;
}

class AccountCreditsSnapshot {
  const AccountCreditsSnapshot({
    required this.hasCredits,
    required this.unlimited,
    this.balance,
  });

  static AccountCreditsSnapshot? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return null;
    }
    return AccountCreditsSnapshot(
      hasCredits: _boolField(map, ['hasCredits', 'has_credits']) ?? false,
      unlimited: _boolValue(map['unlimited']) ?? false,
      balance: _stringValue(map['balance']),
    );
  }

  final bool hasCredits;
  final bool unlimited;
  final String? balance;
}

class AccountSpendControlLimitSnapshot {
  const AccountSpendControlLimitSnapshot({
    this.limit,
    this.used,
    this.remainingPercent,
    this.resetsAt,
  });

  static AccountSpendControlLimitSnapshot? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return null;
    }
    final snapshot = AccountSpendControlLimitSnapshot(
      limit: _stringValue(map['limit']),
      used: _stringValue(map['used']),
      remainingPercent: _intField(map, [
        'remainingPercent',
        'remaining_percent',
      ]),
      resetsAt: _intField(map, ['resetsAt', 'resets_at']),
    );
    return snapshot.hasData ? snapshot : null;
  }

  final String? limit;
  final String? used;
  final int? remainingPercent;
  final int? resetsAt;

  bool get hasData =>
      _hasText(limit) ||
      _hasText(used) ||
      remainingPercent != null ||
      resetsAt != null;
}

class AccountRateLimitResetCreditsSummary {
  const AccountRateLimitResetCreditsSummary({
    required this.availableCount,
    required this.credits,
  });

  static AccountRateLimitResetCreditsSummary? fromJson(Object? value) {
    final map = _objectMap(value);
    if (map.isEmpty) {
      return null;
    }
    return AccountRateLimitResetCreditsSummary(
      availableCount:
          _intField(map, ['availableCount', 'available_count']) ?? 0,
      credits: _resetCredits(map['credits']),
    );
  }

  final int availableCount;
  final List<AccountRateLimitResetCredit>? credits;
}

class AccountRateLimitResetCredit {
  const AccountRateLimitResetCredit({
    required this.id,
    required this.resetType,
    required this.status,
    this.grantedAt,
    this.expiresAt,
    this.title,
    this.description,
  });

  static AccountRateLimitResetCredit? fromJson(Object? value) {
    final map = _objectMap(value);
    final id = _stringValue(map['id']);
    if (id == null) {
      return null;
    }
    return AccountRateLimitResetCredit(
      id: id,
      resetType: _stringField(map, ['resetType', 'reset_type']) ?? 'unknown',
      status: _stringValue(map['status']) ?? 'unknown',
      grantedAt: _intField(map, ['grantedAt', 'granted_at']),
      expiresAt: _intField(map, ['expiresAt', 'expires_at']),
      title: _stringValue(map['title']),
      description: _stringValue(map['description']),
    );
  }

  final String id;
  final String resetType;
  final String status;
  final int? grantedAt;
  final int? expiresAt;
  final String? title;
  final String? description;
}

List<AccountTokenUsageDailyBucket> _dailyBuckets(Object? value) {
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(
    value.map(AccountTokenUsageDailyBucket.fromJson).nonNulls,
  );
}

Map<String, AccountRateLimitsSnapshot> _rateLimitsByLimitId(Object? value) {
  if (value is! Map) {
    return const {};
  }
  final snapshots = <String, AccountRateLimitsSnapshot>{};
  for (final entry in value.entries) {
    final snapshot = AccountRateLimitsSnapshot.fromJson(entry.value);
    if (snapshot != null) {
      snapshots[entry.key.toString()] = snapshot;
    }
  }
  return Map.unmodifiable(snapshots);
}

List<AccountRateLimitResetCredit>? _resetCredits(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! List) {
    return const [];
  }
  return List.unmodifiable(
    value.map(AccountRateLimitResetCredit.fromJson).nonNulls,
  );
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return const {};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

String? _stringField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _stringValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

int? _intField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _intValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

bool? _boolValue(Object? value) => value is bool ? value : null;

bool? _boolField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = _boolValue(map[key]);
    if (value != null) {
      return value;
    }
  }
  return null;
}

Object? _valueField(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value != null) {
      return value;
    }
  }
  return null;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
