import '../../i18n/app_localizations.dart';
import '../../usage/account_usage_snapshot_controller.dart';
import '../../usage/account_usage_snapshot_reader.dart';
import '../../usage/thread_token_usage_controller.dart';

String buildAccountUsageSummary({
  required AppLocalizations l10n,
  AccountUsageSnapshotController? controller,
  ThreadTokenUsageSnapshot? threadUsage,
}) {
  final lines = <String>[l10n.accountUsageStatus];
  if (controller == null) {
    lines.add(l10n.accountUsageUnavailable);
    lines.addAll(threadTokenUsageStatusLines(l10n, threadUsage));
    return lines.join('\n');
  }

  if (controller.status == AccountUsageSnapshotStatus.failed) {
    final error = controller.error;
    lines.add(
      '${l10n.accountUsageLoadFailed}${error == null ? '' : ': $error'}',
    );
    lines.addAll(threadTokenUsageStatusLines(l10n, threadUsage));
    return lines.join('\n');
  }

  final snapshot = controller.snapshot;
  if (snapshot == null) {
    lines.add(l10n.accountUsageUnavailable);
    lines.addAll(threadTokenUsageStatusLines(l10n, threadUsage));
    return lines.join('\n');
  }

  final tokenSummary = _tokenUsageSummary(l10n, snapshot.summary);
  if (tokenSummary.isNotEmpty) {
    lines.add('${l10n.accountUsageTokenSummary}: $tokenSummary');
  }

  final dailyUsage = _dailyUsageSummary(l10n, snapshot.dailyUsageBuckets);
  if (dailyUsage.isNotEmpty) {
    lines.add('${l10n.accountUsageRecentDaily}: $dailyUsage');
  }

  lines.addAll(_rateLimitSummaryLines(l10n, snapshot));

  final resetCredits = snapshot.rateLimitResetCredits;
  if (resetCredits != null) {
    lines.add(
      '${l10n.accountUsageResetCredits}: ${l10n.resetCreditsAvailable(resetCredits.availableCount)}',
    );
  }

  if (lines.length == 1) {
    lines.add(l10n.accountUsageUnavailable);
  }
  lines.addAll(threadTokenUsageStatusLines(l10n, threadUsage));
  return lines.join('\n');
}

Iterable<String> threadTokenUsageStatusLines(
  AppLocalizations l10n,
  ThreadTokenUsageSnapshot? snapshot,
) sync* {
  if (snapshot == null) {
    return;
  }
  yield '${l10n.threadTokenUsageStatus}: ${l10n.threadTokenUsageLast}: ${_threadTokenUsageBreakdownSummary(l10n, snapshot.usage.last)}';
  yield '${l10n.threadTokenUsageStatus}: ${l10n.threadTokenUsageTotal}: ${_threadTokenUsageBreakdownSummary(l10n, snapshot.usage.total)}';
  final modelContextWindow = snapshot.usage.modelContextWindow;
  if (modelContextWindow != null) {
    yield '${l10n.threadTokenUsageContextWindow}: ${l10n.tokenCount(modelContextWindow)}';
  }
}

Iterable<String> accountUsageStatusLines(
  AppLocalizations l10n,
  AccountUsageSnapshotController controller,
) sync* {
  if (controller.status == AccountUsageSnapshotStatus.failed) {
    final error = controller.error;
    yield '${l10n.accountUsageStatus}: ${l10n.accountUsageLoadFailed}${error == null ? '' : ': $error'}';
    return;
  }

  final snapshot = controller.snapshot;
  if (snapshot == null) {
    return;
  }

  final tokenSummary = _tokenUsageSummary(l10n, snapshot.summary);
  if (tokenSummary.isNotEmpty) {
    yield '${l10n.accountUsageStatus}: $tokenSummary';
  }

  final rateLimitSummary = _compactRateLimitSummary(l10n, snapshot);
  if (rateLimitSummary.isNotEmpty) {
    yield '${l10n.accountUsageRateLimits}: $rateLimitSummary';
  }
}

String _tokenUsageSummary(
  AppLocalizations l10n,
  AccountTokenUsageSummary summary,
) {
  final parts = <String>[
    if (summary.lifetimeTokens != null)
      '${l10n.lifetimeTokens}=${l10n.tokenCount(summary.lifetimeTokens!)}',
    if (summary.peakDailyTokens != null)
      '${l10n.peakDailyTokens}=${l10n.tokenCount(summary.peakDailyTokens!)}',
    if (summary.currentStreakDays != null)
      '${l10n.currentStreakDays}=${l10n.dayCount(summary.currentStreakDays!)}',
    if (summary.longestStreakDays != null)
      '${l10n.longestStreakDays}=${l10n.dayCount(summary.longestStreakDays!)}',
    if (summary.longestRunningTurnSec != null)
      '${l10n.longestRunningTurnSec}=${l10n.secondCount(summary.longestRunningTurnSec!)}',
  ];
  return parts.join(', ');
}

String _threadTokenUsageBreakdownSummary(
  AppLocalizations l10n,
  TokenUsageBreakdown breakdown,
) {
  return [
    '${l10n.totalTokens}=${l10n.tokenCount(breakdown.totalTokens)}',
    '${l10n.inputTokens}=${l10n.tokenCount(breakdown.inputTokens)}',
    '${l10n.cachedInputTokens}=${l10n.tokenCount(breakdown.cachedInputTokens)}',
    '${l10n.outputTokens}=${l10n.tokenCount(breakdown.outputTokens)}',
    '${l10n.reasoningOutputTokens}=${l10n.tokenCount(breakdown.reasoningOutputTokens)}',
  ].join(', ');
}

String _dailyUsageSummary(
  AppLocalizations l10n,
  List<AccountTokenUsageDailyBucket> buckets,
) {
  return buckets
      .take(7)
      .map((bucket) => '${bucket.startDate} ${l10n.tokenCount(bucket.tokens)}')
      .join('; ');
}

Iterable<String> _rateLimitSummaryLines(
  AppLocalizations l10n,
  AccountUsageSnapshot snapshot,
) sync* {
  final snapshots = _displayedRateLimitSnapshots(snapshot);
  for (final entry in snapshots) {
    final title = _rateLimitTitle(l10n, entry.key, entry.value);
    final summary = _rateLimitSnapshotSummary(l10n, entry.value);
    if (summary.isNotEmpty) {
      final prefix = title == l10n.accountUsageRateLimits
          ? l10n.accountUsageRateLimits
          : '${l10n.accountUsageRateLimits} ($title)';
      yield '$prefix: $summary';
    }
  }
}

String _compactRateLimitSummary(
  AppLocalizations l10n,
  AccountUsageSnapshot snapshot,
) {
  final snapshots = _displayedRateLimitSnapshots(snapshot);
  if (snapshots.isEmpty) {
    return '';
  }
  return snapshots
      .take(2)
      .map((entry) {
        final title = _rateLimitTitle(l10n, entry.key, entry.value);
        final summary = _rateLimitSnapshotSummary(l10n, entry.value);
        if (summary.isEmpty || title == l10n.accountUsageRateLimits) {
          return summary.isEmpty ? title : summary;
        }
        return '$title: $summary';
      })
      .join('; ');
}

List<MapEntry<String, AccountRateLimitsSnapshot>> _displayedRateLimitSnapshots(
  AccountUsageSnapshot snapshot,
) {
  if (snapshot.rateLimitsByLimitId.isNotEmpty) {
    return snapshot.rateLimitsByLimitId.entries.toList(growable: false);
  }
  final rateLimits = snapshot.rateLimits;
  if (rateLimits == null) {
    return const [];
  }
  return [MapEntry('', rateLimits)];
}

String _rateLimitTitle(
  AppLocalizations l10n,
  String fallback,
  AccountRateLimitsSnapshot snapshot,
) {
  final limitName = snapshot.limitName;
  if (limitName != null && limitName.isNotEmpty) {
    return limitName;
  }
  final limitId = snapshot.limitId;
  if (limitId != null && limitId.isNotEmpty) {
    return limitId;
  }
  if (fallback.isNotEmpty) {
    return fallback;
  }
  return l10n.accountUsageRateLimits;
}

String _rateLimitSnapshotSummary(
  AppLocalizations l10n,
  AccountRateLimitsSnapshot snapshot,
) {
  final parts = <String>[
    _windowSummary(l10n, l10n.primaryRateLimit, snapshot.primary),
    if (snapshot.secondary != null)
      _windowSummary(l10n, l10n.secondaryRateLimit, snapshot.secondary),
    if (snapshot.rateLimitReachedType != null)
      l10n.rateLimitReached(snapshot.rateLimitReachedType!),
    if (snapshot.planType != null) '${l10n.planType}: ${snapshot.planType}',
    if (snapshot.credits != null) _creditsSummary(l10n, snapshot.credits!),
    if (snapshot.individualLimit != null)
      _individualLimitSummary(l10n, snapshot.individualLimit!),
  ].where((part) => part.isNotEmpty).toList(growable: false);
  return parts.join(', ');
}

String _windowSummary(
  AppLocalizations l10n,
  String label,
  AccountRateLimitWindow? window,
) {
  if (window == null) {
    return '$label: ${l10n.rateLimitUnavailable}';
  }
  final parts = <String>[
    if (window.usedPercent != null)
      l10n.rateLimitUsedPercent(window.usedPercent!),
    if (window.windowDurationMins != null)
      l10n.rateLimitWindowMinutes(window.windowDurationMins!),
    if (window.resetsAt != null) l10n.rateLimitResetsAt(window.resetsAt!),
  ];
  if (parts.isEmpty) {
    return '$label: ${l10n.rateLimitUnavailable}';
  }
  return '$label: ${parts.join(', ')}';
}

String _creditsSummary(AppLocalizations l10n, AccountCreditsSnapshot credits) {
  if (credits.unlimited) {
    return '${l10n.creditsStatus}: ${l10n.creditsUnlimited}';
  }
  final parts = <String>[
    credits.hasCredits ? l10n.creditsAvailable : l10n.creditsUnavailable,
    if (credits.balance != null) l10n.creditsBalance(credits.balance!),
  ];
  return '${l10n.creditsStatus}: ${parts.join(', ')}';
}

String _individualLimitSummary(
  AppLocalizations l10n,
  AccountSpendControlLimitSnapshot limit,
) {
  final parts = <String>[
    if (limit.limit != null) limit.limit!,
    if (limit.used != null) l10n.individualLimitUsed(limit.used!),
    if (limit.remainingPercent != null)
      l10n.individualLimitRemaining(limit.remainingPercent!),
    if (limit.resetsAt != null) l10n.rateLimitResetsAt(limit.resetsAt!),
  ];
  if (parts.isEmpty) {
    return '';
  }
  return '${l10n.individualLimit}: ${parts.join(', ')}';
}
