import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/session/reconnect_policy.dart';

void main() {
  test('fixed reconnect policy returns delays and caps at the last value', () {
    const policy = ReconnectPolicy.fixed(
      delays: [Duration(seconds: 1), Duration(seconds: 2)],
    );

    expect(policy.delayForAttempt(1), const Duration(seconds: 1));
    expect(policy.delayForAttempt(2), const Duration(seconds: 2));
    expect(policy.delayForAttempt(3), const Duration(seconds: 2));
  });

  test('reconnect policy rejects invalid attempts and empty schedules', () {
    const policy = ReconnectPolicy.fixed(delays: [Duration(seconds: 1)]);
    const emptyPolicy = ReconnectPolicy.fixed(delays: []);

    expect(() => policy.delayForAttempt(0), throwsArgumentError);
    expect(() => emptyPolicy.delayForAttempt(1), throwsArgumentError);
  });
}
