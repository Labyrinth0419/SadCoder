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
      dailyUsageBuckets: _dailyBuckets(usageJson['dailyUsageBuckets']),
      rateLimits: AccountRateLimitsSnapshot.fromJson(
        rateLimitsJson['rateLimits'],
      ),
      rateLimitsByLimitId: _rateLimitsByLimitId(
        rateLimitsJson['rateLimitsByLimitId'],
      ),
      rateLimitResetCredits: AccountRateLimitResetCreditsSummary.fromJson(
        rateLimitsJson['rateLimitResetCredits'],
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
      lifetimeTokens: _intValue(map['lifetimeTokens']),
      peakDailyTokens: _intValue(map['peakDailyTokens']),
      longestRunningTurnSec: _intValue(map['longestRunningTurnSec']),
      currentStreakDays: _intValue(map['currentStreakDays']),
      longestStreakDays: _intValue(map['longestStreakDays']),
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
    final startDate = _stringValue(map['startDate']);
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
      limitId: _stringValue(map['limitId']),
      limitName: _stringValue(map['limitName']),
      primary: AccountRateLimitWindow.fromJson(map['primary']),
      secondary: AccountRateLimitWindow.fromJson(map['secondary']),
      credits: AccountCreditsSnapshot.fromJson(map['credits']),
      individualLimit: AccountSpendControlLimitSnapshot.fromJson(
        map['individualLimit'],
      ),
      planType: _stringValue(map['planType']),
      rateLimitReachedType: _stringValue(map['rateLimitReachedType']),
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
      usedPercent: _intValue(map['usedPercent']),
      windowDurationMins: _intValue(map['windowDurationMins']),
      resetsAt: _intValue(map['resetsAt']),
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
      hasCredits: map['hasCredits'] == true,
      unlimited: map['unlimited'] == true,
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
      remainingPercent: _intValue(map['remainingPercent']),
      resetsAt: _intValue(map['resetsAt']),
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
      availableCount: _intValue(map['availableCount']) ?? 0,
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
      resetType: _stringValue(map['resetType']) ?? 'unknown',
      status: _stringValue(map['status']) ?? 'unknown',
      grantedAt: _intValue(map['grantedAt']),
      expiresAt: _intValue(map['expiresAt']),
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

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
