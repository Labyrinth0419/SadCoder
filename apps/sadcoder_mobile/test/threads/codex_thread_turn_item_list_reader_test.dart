import 'package:flutter_test/flutter_test.dart';
import 'package:sadcoder_mobile/src/protocol/codex_app_server_client.dart';
import 'package:sadcoder_mobile/src/protocol/json_rpc.dart';
import 'package:sadcoder_mobile/src/threads/codex_thread_item_list_reader.dart';
import 'package:sadcoder_mobile/src/threads/codex_thread_turn_list_reader.dart';

void main() {
  test('listTurns forwards pagination and item view params', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'data': [
          {
            'id': 'turn_1',
            'status': 'completed',
            'itemsView': 'summary',
            'items': <Object?>[],
          },
        ],
        'nextCursor': 'older',
        'backwardsCursor': 'newer',
      };
    });
    final reader = CodexThreadTurnListReader(CodexAppServerClient(transport));

    final page = await reader.listTurns(
      threadId: 'thr_1',
      cursor: ' older_cursor ',
      limit: 25,
      sortDirection: 'desc',
      itemsView: 'summary',
    );

    expect(requests.single.method, 'thread/turns/list');
    expect(requests.single.params, {
      'threadId': 'thr_1',
      'cursor': 'older_cursor',
      'limit': 25,
      'sortDirection': 'desc',
      'itemsView': 'summary',
    });
    expect(page.turns.single.id, 'turn_1');
    expect(page.nextCursor, 'older');
    expect(page.backwardsCursor, 'newer');
  });

  test('listItems forwards optional turn and pagination params', () async {
    final requests = <JsonRpcRequest>[];
    final transport = MemoryJsonRpcTransport((request) {
      requests.add(request);
      return {
        'data': [
          {'id': 'item_1', 'type': 'agentMessage', 'text': 'Recovered item'},
        ],
        'nextCursor': 'next_item',
        'backwardsCursor': 'previous_item',
      };
    });
    final reader = CodexThreadItemListReader(CodexAppServerClient(transport));

    final page = await reader.listItems(
      threadId: 'thr_1',
      turnId: ' turn_1 ',
      cursor: ' item_cursor ',
      limit: 50,
      sortDirection: 'asc',
    );

    expect(requests.single.method, 'thread/items/list');
    expect(requests.single.params, {
      'threadId': 'thr_1',
      'turnId': 'turn_1',
      'cursor': 'item_cursor',
      'limit': 50,
      'sortDirection': 'asc',
    });
    expect(page.items.single.id, 'item_1');
    expect(page.items.single.text, 'Recovered item');
    expect(page.nextCursor, 'next_item');
    expect(page.backwardsCursor, 'previous_item');
  });
}
