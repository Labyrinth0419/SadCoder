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
