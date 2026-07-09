import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/accounts/account_snapshot_reader.dart';

void main() {
  test('AccountSnapshot parses unauthenticated states', () {
    final required = AccountSnapshot.fromJson({
      'account': null,
      'requiresOpenaiAuth': true,
    });
    final notRequired = AccountSnapshot.fromJson({'requiresOpenaiAuth': false});

    expect(required.account, isNull);
    expect(required.isAuthenticated, false);
    expect(required.requiresOpenaiAuth, true);
    expect(notRequired.requiresOpenaiAuth, false);
  });

  test('AccountSnapshot parses known account types', () {
    final chatgpt = AccountSnapshot.fromJson({
      'account': {
        'type': 'chatgpt',
        'email': 'user@example.com',
        'planType': 'pro',
      },
      'requiresOpenaiAuth': true,
    });
    final apiKey = AccountSnapshot.fromJson({
      'account': {'type': 'apiKey'},
      'requiresOpenaiAuth': true,
    });
    final bedrock = AccountSnapshot.fromJson({
      'account': {'type': 'amazonBedrock', 'credentialSource': 'awsManaged'},
      'requiresOpenaiAuth': false,
    });

    expect(chatgpt.account?.label, 'ChatGPT / user@example.com / pro');
    expect(apiKey.account?.label, 'API key');
    expect(bedrock.account?.label, 'Amazon Bedrock / awsManaged');
  });

  test('AccountSnapshot preserves unknown account type labels', () {
    final snapshot = AccountSnapshot.fromJson({
      'account': {'type': 'customProvider'},
      'requiresOpenaiAuth': false,
    });

    expect(snapshot.account?.label, 'customProvider');
  });
}
