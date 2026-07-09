import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/security/log_redactor.dart';

void main() {
  const redactor = LogRedactor.defaultRedactor;

  test('redacts sensitive keys from nested structured payloads', () {
    final redacted =
        redactor.redactValue({
              'method': 'turn/start',
              'params': {
                'cwd': '/repo',
                'command': 'cargo test',
                'password': 'secret-password',
                'privateKeyPem': '-----BEGIN PRIVATE KEY-----secret',
                'headers': {
                  'Authorization': 'Bearer access-secret',
                  'Cookie': 'session=abc',
                },
                'tokens': [
                  {'access_token': 'token-1'},
                  {'refresh-token': 'token-2'},
                  {'safe': 'value'},
                ],
              },
            })
            as Map<Object?, Object?>;

    final params = redacted['params'] as Map<Object?, Object?>;
    expect(params['cwd'], '/repo');
    expect(params['command'], 'cargo test');
    expect(params['password'], '[REDACTED]');
    expect(params['privateKeyPem'], '[REDACTED]');

    final headers = params['headers'] as Map<Object?, Object?>;
    expect(headers['Authorization'], '[REDACTED]');
    expect(headers['Cookie'], '[REDACTED]');

    final tokens = params['tokens'] as List<Object?>;
    expect((tokens[0] as Map<Object?, Object?>)['access_token'], '[REDACTED]');
    expect((tokens[1] as Map<Object?, Object?>)['refresh-token'], '[REDACTED]');
    expect((tokens[2] as Map<Object?, Object?>)['safe'], 'value');
  });

  test('redacts JSON strings while preserving non-sensitive fields', () {
    final redacted = redactor.redactJsonString(
      jsonEncode({
        'path': '/repo/lib/main.dart',
        'apiKey': 'sk-abcdefghijklmnopqrstuvwxyz',
        'nested': {'client_secret': 'client-secret'},
      }),
    );
    final decoded = jsonDecode(redacted) as Map<String, Object?>;

    expect(decoded['path'], '/repo/lib/main.dart');
    expect(decoded['apiKey'], '[REDACTED]');
    expect(
      (decoded['nested'] as Map<String, Object?>)['client_secret'],
      '[REDACTED]',
    );
  });

  test(
    'redacts authorization headers cookies and key-value secrets in text',
    () {
      final redacted = redactor.redactText(
        'Authorization: Bearer access-secret\n'
        'Cookie: session=abc; csrftoken=def\n'
        'password=hunter2 api_key: sk-abcdefghijklmnopqrstuvwxyz '
        'access_token=token-123 path=/repo',
      );

      expect(redacted, contains('Authorization: Bearer [REDACTED]'));
      expect(redacted, contains('Cookie: [REDACTED]'));
      expect(redacted, contains('password=[REDACTED]'));
      expect(redacted, contains('api_key: [REDACTED]'));
      expect(redacted, contains('access_token=[REDACTED]'));
      expect(redacted, contains('path=/repo'));
      expect(redacted, isNot(contains('hunter2')));
      expect(redacted, isNot(contains('access-secret')));
      expect(redacted, isNot(contains('session=abc')));
      expect(redacted, isNot(contains('sk-abcdefghijklmnopqrstuvwxyz')));
    },
  );

  test('redacts private key blocks from multiline text', () {
    final redacted = redactor.redactText(
      'before\n'
      '-----BEGIN OPENSSH PRIVATE KEY-----\n'
      'super-secret-key-material\n'
      '-----END OPENSSH PRIVATE KEY-----\n'
      'after',
    );

    expect(redacted, contains('before'));
    expect(redacted, contains('[REDACTED]'));
    expect(redacted, contains('after'));
    expect(redacted, isNot(contains('super-secret-key-material')));
    expect(redacted, isNot(contains('BEGIN OPENSSH PRIVATE KEY')));
  });

  test('falls back to text redaction for non-json strings', () {
    final redacted = redactor.redactJsonString(
      'Set-Cookie: auth=abc\nopenai_api_key=sk-abcdefghijklmnopqrstuvwxyz',
    );

    expect(redacted, contains('Set-Cookie: [REDACTED]'));
    expect(redacted, contains('openai_api_key=[REDACTED]'));
    expect(redacted, isNot(contains('auth=abc')));
    expect(redacted, isNot(contains('sk-abcdefghijklmnopqrstuvwxyz')));
  });
}
