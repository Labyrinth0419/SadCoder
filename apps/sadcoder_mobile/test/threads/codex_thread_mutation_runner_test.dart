import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/config/codex_config_overrides.dart';
import 'package:sadcoder_mobile/src/events/guardian_assessment_event.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/threads/codex_thread_mutation_runner.dart';
import 'package:sadcoder_mobile/src/threads/side_conversation.dart';

void main() {
  test(
    'forkThread returns the forked thread from app-server response',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {
          'thread': {
            'id': 'thr_fork',
            'sessionId': 'sess_1',
            'preview': 'Forked work',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 1,
            'forkedFromId': 'thr_source',
            'turns': <Object?>[],
          },
        };
      });
      final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));

      final thread = await runner.forkThread(threadId: 'thr_source');

      expect(thread.id, 'thr_fork');
      expect(thread.forkedFromId, 'thr_source');
      expect(requests.single.method, 'thread/fork');
      expect(requests.single.params, {'threadId': 'thr_source'});
    },
  );

  test('rewindThread forks from the requested turn checkpoint', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'thread': {
          'id': 'thr_rewind',
          'sessionId': 'sess_1',
          'preview': 'Rewound work',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 2,
          'forkedFromId': 'thr_source',
          'turns': <Object?>[],
        },
      };
    });
    final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));

    final thread = await runner.rewindThread(
      threadId: 'thr_source',
      lastTurnId: 'turn_2',
    );

    expect(thread.id, 'thr_rewind');
    expect(thread.forkedFromId, 'thr_source');
    expect(requests.single.method, 'thread/fork');
    expect(requests.single.params, {
      'threadId': 'thr_source',
      'lastTurnId': 'turn_2',
    });
  });

  test(
    'duplicateThread forks the current thread without a checkpoint',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        return {
          'thread': {
            'id': 'thr_duplicate',
            'sessionId': 'sess_1',
            'preview': 'Duplicated work',
            'ephemeral': false,
            'status': 'idle',
            'cwd': '/repo',
            'updatedAt': 2,
            'forkedFromId': 'thr_source',
            'turns': <Object?>[],
          },
        };
      });
      final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));

      final thread = await runner.duplicateThread(threadId: 'thr_source');

      expect(thread.id, 'thr_duplicate');
      expect(thread.forkedFromId, 'thr_source');
      expect(requests.single.method, 'thread/fork');
      expect(requests.single.params, {'threadId': 'thr_source'});
    },
  );

  test('compactThread starts server compaction for the thread', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });
    final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));

    await runner.compactThread(threadId: 'thr_1');

    expect(requests.single.method, 'thread/compact/start');
    expect(requests.single.params, {'threadId': 'thr_1'});
  });

  test('updateThreadSettings forwards explicit thread overrides', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });
    final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));

    await runner.updateThreadSettings(
      threadId: 'thr_1',
      overrides: const CodexConfigOverrides(
        model: 'gpt-5-codex',
        effort: 'medium',
        cwd: '/repo',
      ),
    );

    expect(requests.single.method, 'thread/settings/update');
    expect(requests.single.params, {
      'threadId': 'thr_1',
      'model': 'gpt-5-codex',
      'effort': 'medium',
      'cwd': '/repo',
    });
  });

  test('approveGuardianDeniedAction forwards the guardian event', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {};
    });
    final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));
    const event = GuardianAssessmentEvent(
      id: 'review_1',
      threadId: 'thr_1',
      turnId: 'turn_1',
      startedAtMs: 1000,
      status: 'denied',
      action: {
        'type': 'command',
        'source': 'shell',
        'command': 'rm -rf /tmp/test',
        'cwd': '/repo',
      },
    );

    await runner.approveGuardianDeniedAction(threadId: 'thr_1', event: event);

    expect(requests.single.method, 'thread/approveGuardianDeniedAction');
    expect(requests.single.params?['threadId'], 'thr_1');
    expect((requests.single.params?['event'] as Map)['id'], 'review_1');
  });

  test('unarchiveThread returns the restored thread', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'thread': {
          'id': 'thr_unarchived',
          'sessionId': 'sess_1',
          'preview': 'Restored work',
          'ephemeral': false,
          'status': 'idle',
          'cwd': '/repo',
          'updatedAt': 3,
          'turns': <Object?>[],
        },
      };
    });
    final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));

    final thread = await runner.unarchiveThread(threadId: 'thr_archived');

    expect(thread.id, 'thr_unarchived');
    expect(thread.title, 'Restored work');
    expect(requests.single.method, 'thread/unarchive');
    expect(requests.single.params, {'threadId': 'thr_archived'});
  });

  test(
    'startSideConversation forks an ephemeral thread and injects boundary',
    () async {
      final requests = <JsonRpcRequest>[];
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        if (request.method == 'thread/fork') {
          return {
            'thread': {
              'id': 'thr_side',
              'sessionId': 'sess_1',
              'preview': 'Side work',
              'ephemeral': true,
              'status': 'idle',
              'cwd': '/repo',
              'updatedAt': 2,
              'forkedFromId': 'thr_parent',
              'turns': <Object?>[],
            },
          };
        }
        return {};
      });
      final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));

      final thread = await runner.startSideConversation(threadId: 'thr_parent');

      expect(thread.id, 'thr_side');
      expect(thread.ephemeral, true);
      expect(requests.map((request) => request.method), [
        'thread/fork',
        'thread/inject_items',
      ]);
      expect(requests[0].params, {
        'threadId': 'thr_parent',
        'developerInstructions': SideConversationPrompts.developerInstructions,
        'ephemeral': true,
      });
      expect(requests[1].params, {
        'threadId': 'thr_side',
        'items': [SideConversationPrompts.boundaryPromptItem()],
      });
    },
  );

  test(
    'startSideConversation deletes the side thread when injection fails',
    () async {
      final requests = <JsonRpcRequest>[];
      final injectError = StateError('inject failed');
      final transport = MemoryJsonRpcTransport((request) {
        requests.add(request);
        if (request.method == 'thread/fork') {
          return {
            'thread': {
              'id': 'thr_side',
              'sessionId': 'sess_1',
              'preview': 'Side work',
              'ephemeral': true,
              'status': 'idle',
              'cwd': '/repo',
              'updatedAt': 2,
              'forkedFromId': 'thr_parent',
              'turns': <Object?>[],
            },
          };
        }
        if (request.method == 'thread/inject_items') {
          throw injectError;
        }
        return {};
      });
      final runner = CodexThreadMutationRunner(CodexAppServerClient(transport));

      await expectLater(
        runner.startSideConversation(threadId: 'thr_parent'),
        throwsA(same(injectError)),
      );

      expect(requests.map((request) => request.method), [
        'thread/fork',
        'thread/inject_items',
        'thread/delete',
      ]);
      expect(requests.last.params, {'threadId': 'thr_side'});
    },
  );
}
