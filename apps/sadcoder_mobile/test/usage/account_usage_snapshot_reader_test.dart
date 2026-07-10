import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/usage/account_usage_snapshot_reader.dart';
import 'package:sadcoder_mobile/src/usage/codex_account_usage_snapshot_reader.dart';

void main() {
  test('AccountUsageSnapshot parses usage and rate-limit payloads', () {
    final snapshot = AccountUsageSnapshot.fromJson(
      usageJson: {
        'summary': {
          'lifetimeTokens': 1234,
          'peakDailyTokens': 900,
          'longestRunningTurnSec': 120,
          'currentStreakDays': 3,
          'longestStreakDays': 4,
        },
        'dailyUsageBuckets': [
          {'startDate': '2026-07-08', 'tokens': 111},
          {'startDate': '2026-07-09', 'tokens': 222},
          {'tokens': 333},
        ],
      },
      rateLimitsJson: {
        'rateLimits': {
          'limitId': 'codex',
          'limitName': 'Codex',
          'primary': {
            'usedPercent': 25,
            'windowDurationMins': 15,
            'resetsAt': 1730947200,
          },
          'credits': {
            'hasCredits': true,
            'unlimited': false,
            'balance': r'$10',
          },
          'individualLimit': {
            'limit': r'$20',
            'used': r'$5',
            'remainingPercent': 75,
            'resetsAt': 1784246400,
          },
          'planType': 'pro',
          'rateLimitReachedType': 'workspace_member_usage_limit_reached',
        },
        'rateLimitsByLimitId': {
          'codex': {
            'limitId': 'codex',
            'primary': {'usedPercent': 40},
          },
        },
        'rateLimitResetCredits': {
          'availableCount': 2,
          'credits': [
            {
              'id': 'RateLimitResetCredit_1',
              'resetType': 'codexRateLimits',
              'status': 'available',
              'grantedAt': 1781654400,
              'expiresAt': 1784246400,
              'title': 'Full reset',
              'description': 'Ready to redeem',
            },
          ],
        },
      },
    );

    expect(snapshot.summary.lifetimeTokens, 1234);
    expect(snapshot.dailyUsageBuckets, hasLength(2));
    expect(snapshot.dailyUsageBuckets.last.tokens, 222);
    expect(snapshot.rateLimits?.limitName, 'Codex');
    expect(snapshot.rateLimits?.primary?.usedPercent, 25);
    expect(snapshot.rateLimits?.credits?.balance, r'$10');
    expect(snapshot.rateLimits?.individualLimit?.remainingPercent, 75);
    expect(snapshot.rateLimitsByLimitId['codex']?.primary?.usedPercent, 40);
    expect(snapshot.rateLimitResetCredits?.availableCount, 2);
    expect(
      snapshot.rateLimitResetCredits?.credits?.single.id,
      'RateLimitResetCredit_1',
    );
  });

  test(
    'AccountUsageSnapshot parses snake_case usage and rate-limit payloads',
    () {
      final snapshot = AccountUsageSnapshot.fromJson(
        usageJson: {
          'summary': {
            'lifetime_tokens': 4321,
            'peak_daily_tokens': 1200,
            'longest_running_turn_sec': 240,
            'current_streak_days': 5,
            'longest_streak_days': 6,
          },
          'daily_usage_buckets': [
            {'start_date': '2026-07-10', 'tokens': 444},
          ],
        },
        rateLimitsJson: {
          'rate_limits': {
            'limit_id': 'codex',
            'limit_name': 'Codex Pro',
            'primary': {
              'used_percent': 55,
              'window_duration_mins': 30,
              'resets_at': 1784246400,
            },
            'credits': {
              'has_credits': true,
              'unlimited': false,
              'balance': r'$8',
            },
            'individual_limit': {
              'limit': r'$25',
              'used': r'$10',
              'remaining_percent': 60,
              'resets_at': 1784332800,
            },
            'plan_type': 'team',
            'rate_limit_reached_type': 'primary_limit_reached',
          },
          'rate_limits_by_limit_id': {
            'codex': {
              'limit_id': 'codex',
              'primary': {'used_percent': 70},
            },
          },
          'rate_limit_reset_credits': {
            'available_count': 1,
            'credits': [
              {
                'id': 'RateLimitResetCredit_2',
                'reset_type': 'codexRateLimits',
                'status': 'available',
                'granted_at': 1781654400,
                'expires_at': 1784246400,
                'title': 'Team reset',
                'description': 'Ready',
              },
            ],
          },
        },
      );

      expect(snapshot.summary.lifetimeTokens, 4321);
      expect(snapshot.summary.peakDailyTokens, 1200);
      expect(snapshot.summary.longestRunningTurnSec, 240);
      expect(snapshot.summary.currentStreakDays, 5);
      expect(snapshot.summary.longestStreakDays, 6);
      expect(snapshot.dailyUsageBuckets.single.startDate, '2026-07-10');
      expect(snapshot.rateLimits?.limitName, 'Codex Pro');
      expect(snapshot.rateLimits?.primary?.usedPercent, 55);
      expect(snapshot.rateLimits?.primary?.windowDurationMins, 30);
      expect(snapshot.rateLimits?.primary?.resetsAt, 1784246400);
      expect(snapshot.rateLimits?.credits?.hasCredits, true);
      expect(snapshot.rateLimits?.credits?.balance, r'$8');
      expect(snapshot.rateLimits?.individualLimit?.remainingPercent, 60);
      expect(snapshot.rateLimits?.planType, 'team');
      expect(
        snapshot.rateLimits?.rateLimitReachedType,
        'primary_limit_reached',
      );
      expect(snapshot.rateLimitsByLimitId['codex']?.primary?.usedPercent, 70);
      expect(snapshot.rateLimitResetCredits?.availableCount, 1);
      final credit = snapshot.rateLimitResetCredits?.credits?.single;
      expect(credit?.id, 'RateLimitResetCredit_2');
      expect(credit?.resetType, 'codexRateLimits');
      expect(credit?.grantedAt, 1781654400);
      expect(credit?.expiresAt, 1784246400);
    },
  );

  test(
    'CodexAccountUsageSnapshotReader calls usage and rate-limit reads',
    () async {
      final methods = <String>[];
      final transport = MemoryJsonRpcTransport((request) {
        methods.add(request.method);
        return switch (request.method) {
          'account/usage/read' => {
            'summary': {'lifetimeTokens': 1234},
            'dailyUsageBuckets': <Object?>[],
          },
          'account/rateLimits/read' => {
            'rateLimits': {
              'primary': {'usedPercent': 25},
            },
            'rateLimitResetCredits': {'availableCount': 2},
          },
          _ => <String, Object?>{},
        };
      });
      final reader = CodexAccountUsageSnapshotReader(
        CodexAppServerClient(transport),
      );

      final snapshot = await reader.readUsage();

      expect(methods, ['account/usage/read', 'account/rateLimits/read']);
      expect(snapshot.summary.lifetimeTokens, 1234);
      expect(snapshot.rateLimits?.primary?.usedPercent, 25);
      expect(snapshot.rateLimitResetCredits?.availableCount, 2);
    },
  );
}
