import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/agent/agent_logs.dart';

void main() {
  test('fromJson redacts service log content and errors by default', () {
    final result = AgentLogsResult.fromJson({
      'schemaVersion': 1,
      'maxTailBytes': 262144,
      'logs': [
        {
          'name': 'app-server.stderr',
          'path': '/home/tester/.sadcoder/app-server.stderr.log',
          'exists': true,
          'sizeBytes': 4096,
          'tailBytes': 256,
          'truncated': true,
          'content':
              'Authorization: Bearer access-secret\n'
              'password=hunter2\n'
              '-----BEGIN OPENSSH PRIVATE KEY-----\n'
              'super-secret-key-material\n'
              '-----END OPENSSH PRIVATE KEY-----\n'
              'path=/repo',
          'error': 'failed with api_key=sk-abcdefghijklmnopqrstuvwxyz',
        },
      ],
    });

    final log = result.logs.single;
    expect(log.path, '/home/tester/.sadcoder/app-server.stderr.log');
    expect(log.content, contains('Authorization: Bearer [REDACTED]'));
    expect(log.content, contains('password=[REDACTED]'));
    expect(log.content, contains('path=/repo'));
    expect(log.content, isNot(contains('access-secret')));
    expect(log.content, isNot(contains('hunter2')));
    expect(log.content, isNot(contains('super-secret-key-material')));
    expect(log.content, isNot(contains('BEGIN OPENSSH PRIVATE KEY')));
    expect(log.error, 'failed with api_key=[REDACTED]');
  });

  test('redacted sanitizes constructed log results before UI display', () {
    const result = AgentLogsResult(
      schemaVersion: 1,
      maxTailBytes: 1024,
      logs: [
        AgentLogEntry(
          name: 'app-server.stderr',
          path: '/tmp/app-server.stderr.log',
          exists: true,
          sizeBytes: 24,
          tailBytes: 24,
          truncated: false,
          content: 'Cookie: session=abc\naccess_token=token-123',
          error: 'private_key=secret-key',
        ),
      ],
    );

    final redacted = result.redacted();

    expect(redacted.logs.single.content, contains('Cookie: [REDACTED]'));
    expect(redacted.logs.single.content, contains('access_token=[REDACTED]'));
    expect(redacted.logs.single.content, isNot(contains('session=abc')));
    expect(redacted.logs.single.content, isNot(contains('token-123')));
    expect(redacted.logs.single.error, 'private_key=[REDACTED]');
  });
}
