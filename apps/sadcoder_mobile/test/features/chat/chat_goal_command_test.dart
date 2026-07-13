import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/features/chat/chat_goal_command.dart';

void main() {
  group('parseChatGoalCommand', () {
    test('parses empty show and get as read commands', () {
      expect(parseChatGoalCommand(''), isA<ChatGoalGetCommand>());
      expect(parseChatGoalCommand('   '), isA<ChatGoalGetCommand>());
      expect(parseChatGoalCommand('show'), isA<ChatGoalGetCommand>());
      expect(parseChatGoalCommand('get'), isA<ChatGoalGetCommand>());
    });

    test('parses clear command', () {
      expect(parseChatGoalCommand('clear'), isA<ChatGoalClearCommand>());
    });

    test('parses default and explicit set objectives', () {
      final defaultSet = parseChatGoalCommand('Ship goal support');
      expect(defaultSet, isA<ChatGoalSetCommand>());
      expect((defaultSet as ChatGoalSetCommand).objective, 'Ship goal support');
      expect(defaultSet.status, isNull);
      expect(defaultSet.tokenBudget, isNull);

      final explicitSet = parseChatGoalCommand('set Reduce latency');
      expect(explicitSet, isA<ChatGoalSetCommand>());
      expect((explicitSet as ChatGoalSetCommand).objective, 'Reduce latency');
    });

    test('rejects explicit set without an objective', () {
      expect(parseChatGoalCommand('set'), isNull);
      expect(parseChatGoalCommand('set   '), isNull);
    });

    test('parses supported status values and rejects unsupported values', () {
      for (final status in const [
        'active',
        'paused',
        'blocked',
        'usageLimited',
        'budgetLimited',
        'complete',
      ]) {
        final command = parseChatGoalCommand('status $status');
        expect(command, isA<ChatGoalSetCommand>());
        expect((command as ChatGoalSetCommand).status, status);
        expect(command.objective, isNull);
        expect(command.tokenBudget, isNull);
      }

      expect(parseChatGoalCommand('status sideways'), isNull);
      expect(parseChatGoalCommand('status'), isNull);
    });

    test('parses positive token budgets with optional objectives', () {
      final budgetOnly = parseChatGoalCommand('budget 7500');
      expect(budgetOnly, isA<ChatGoalSetCommand>());
      expect((budgetOnly as ChatGoalSetCommand).tokenBudget, 7500);
      expect(budgetOnly.objective, isNull);

      final withObjective = parseChatGoalCommand(
        'budget 12000 Finish benchmark',
      );
      expect(withObjective, isA<ChatGoalSetCommand>());
      expect((withObjective as ChatGoalSetCommand).tokenBudget, 12000);
      expect(withObjective.objective, 'Finish benchmark');
      expect(withObjective.status, isNull);
    });

    test('rejects invalid token budgets', () {
      expect(parseChatGoalCommand('budget'), isNull);
      expect(parseChatGoalCommand('budget 0'), isNull);
      expect(parseChatGoalCommand('budget -5'), isNull);
      expect(parseChatGoalCommand('budget many'), isNull);
    });
  });
}
